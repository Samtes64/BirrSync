package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strings"
	"time"
	"unicode"

	"github.com/birrsync/birrsync-server/internal/models"
	"github.com/birrsync/birrsync-server/internal/services"
)

type PaymentsHandler struct {
	db       *sql.DB
	telegram services.TelegramNotifier
	webhooks services.WebhookDispatcher
}

func NewPaymentsHandler(db *sql.DB, tg services.TelegramNotifier, wh services.WebhookDispatcher) *PaymentsHandler {
	return &PaymentsHandler{
		db:       db,
		telegram: tg,
		webhooks: wh,
	}
}

// Verify matches an expected transaction and atomically marks it CLAIMED
func (h *PaymentsHandler) Verify(w http.ResponseWriter, r *http.Request) {
	var req models.VerifyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Malformed JSON payload"})
		return
	}

	if req.ExpectedAmount <= 0 {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "expected_amount must be greater than 0"})
		return
	}

	if req.MaxAgeMinutes <= 0 {
		req.MaxAgeMinutes = 30
	}

	req.TransactionID = models.CleanTransactionID(req.TransactionID)
	cleanPhone := cleanPhoneNumber(req.SenderPhone)

	if req.TransactionID == "" && cleanPhone == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Must specify either transaction_id or sender_phone"})
		return
	}

	tx, err := h.db.BeginTx(r.Context(), nil)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to initiate database transaction"})
		return
	}
	defer tx.Rollback()

	var id int
	var txnID, provider string
	var senderName, maskedPhone sql.NullString
	var amount float64
	var createdAt time.Time

	if req.TransactionID != "" {
		// 1. Direct match on Telebirr/CBE Transaction ID
		query := `
			SELECT id, transaction_id, provider, amount, sender_name, masked_phone, created_at 
			FROM transactions 
			WHERE transaction_id = $1 AND amount >= $2 AND status = 'UNCLAIMED'
			FOR UPDATE
		`
		err = tx.QueryRowContext(r.Context(), query, req.TransactionID, req.ExpectedAmount).
			Scan(&id, &txnID, &provider, &amount, &senderName, &maskedPhone, &createdAt)
	} else {
		// 2. Match on last 4 digits (phone suffix)
		if len(cleanPhone) < 4 {
			w.Header().Set("Content-Type", "application/json")
			w.WriteHeader(http.StatusBadRequest)
			json.NewEncoder(w).Encode(map[string]string{"error": "sender_phone must have at least 4 digits"})
			return
		}
		suffix := cleanPhone[len(cleanPhone)-4:]

		query := `
			SELECT id, transaction_id, provider, amount, sender_name, masked_phone, created_at 
			FROM transactions 
			WHERE phone_suffix = $1 
			  AND amount >= $2 
			  AND status = 'UNCLAIMED'
			  AND created_at >= NOW() - ($3 || ' minutes')::INTERVAL
			ORDER BY created_at DESC 
			LIMIT 1
			FOR UPDATE
		`
		err = tx.QueryRowContext(r.Context(), query, suffix, req.ExpectedAmount, req.MaxAgeMinutes).
			Scan(&id, &txnID, &provider, &amount, &senderName, &maskedPhone, &createdAt)
	}

	if err == sql.ErrNoRows {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]interface{}{
			"verified": false,
			"error":    "Payment not found, amount insufficient, expired, or already claimed",
		})
		return
	} else if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Database query error: " + err.Error()})
		return
	}

	// Atomically claim the matched transaction
	claimedAt := time.Now().UTC()
	updateQuery := `
		UPDATE transactions 
		SET status = 'CLAIMED', 
		    claimed_by_app_id = $1, 
		    claimed_by_user_id = $2, 
		    claimed_at = $3 
		WHERE id = $4
	`
	_, err = tx.ExecContext(r.Context(), updateQuery, nullIfEmpty(req.AppID), nullIfEmpty(req.UserID), claimedAt, id)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Failed to claim transaction"})
		return
	}

	if err := tx.Commit(); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Transaction commit failed"})
		return
	}

	claimedTxn := &models.Transaction{
		ID:            id,
		TransactionID: txnID,
		Provider:      provider,
		Amount:        amount,
		SenderName:    senderName.String,
		MaskedPhone:   maskedPhone.String,
		Status:        "CLAIMED",
		ClaimedAt:     &claimedAt,
		CreatedAt:     createdAt,
	}

	if h.webhooks != nil {
		h.webhooks.Dispatch("payment.verified", claimedTxn)
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(models.VerifyResponse{
		Verified:      true,
		TransactionID: txnID,
		Provider:      provider,
		Amount:        amount,
		SenderName:    senderName.String,
		MaskedPhone:   maskedPhone.String,
		PaidAt:        createdAt,
		ClaimedAt:     claimedAt,
	})
}

func cleanPhoneNumber(input string) string {
	var sb strings.Builder
	for _, r := range input {
		if unicode.IsDigit(r) {
			sb.WriteRune(r)
		}
	}
	return sb.String()
}

func nullIfEmpty(s string) interface{} {
	trimmed := strings.TrimSpace(s)
	if trimmed == "" {
		return nil
	}
	return trimmed
}
