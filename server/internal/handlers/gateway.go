package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"time"

	"github.com/birrsync/birrsync-server/internal/middleware"
	"github.com/birrsync/birrsync-server/internal/models"
	"github.com/birrsync/birrsync-server/internal/services"
)

type GatewayHandler struct {
	db       *sql.DB
	telegram services.TelegramNotifier
	webhooks services.WebhookDispatcher
}

func NewGatewayHandler(db *sql.DB, tg services.TelegramNotifier, wh services.WebhookDispatcher) *GatewayHandler {
	return &GatewayHandler{
		db:       db,
		telegram: tg,
		webhooks: wh,
	}
}

// Ingest handles incoming payment receipts forwarded by the Flutter agent
func (h *GatewayHandler) Ingest(w http.ResponseWriter, r *http.Request) {
	gatewayIDVal := r.Context().Value(middleware.GatewayIDContextKey)
	gatewayID, _ := gatewayIDVal.(string)
	if gatewayID == "" {
		gatewayID = r.Header.Get("X-Gateway-ID")
	}

	var req models.IngestRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Malformed JSON payload"})
		return
	}

	req.TransactionID = models.CleanTransactionID(req.TransactionID)
	if req.TransactionID == "" {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Missing transaction_id"})
		return
	}

	if req.Amount <= 0 {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "Invalid or non-positive amount"})
		return
	}

	if req.Provider == "" {
		req.Provider = "TELEBIRR"
	}

	query := `
		INSERT INTO transactions 
		(gateway_id, transaction_id, provider, amount, masked_phone, phone_suffix, sender_name, raw_text)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		ON CONFLICT (transaction_id) DO NOTHING
		RETURNING id, created_at;
	`

	var id int
	var createdAt time.Time
	err := h.db.QueryRowContext(r.Context(), query,
		gatewayID, req.TransactionID, req.Provider, req.Amount,
		req.MaskedPhone, req.PhoneSuffix, req.SenderName, req.Raw,
	).Scan(&id, &createdAt)

	status := "recorded"
	if err == sql.ErrNoRows {
		// Already ingested previously (idempotent)
		status = "already_exists"
	} else if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": "Database error persisting transaction: " + err.Error()})
		return
	}

	if status == "recorded" {
		txn := &models.Transaction{
			ID:            id,
			GatewayID:     gatewayID,
			TransactionID: req.TransactionID,
			Provider:      req.Provider,
			Amount:        req.Amount,
			MaskedPhone:   req.MaskedPhone,
			PhoneSuffix:   req.PhoneSuffix,
			SenderName:    req.SenderName,
			RawText:       req.Raw,
			Status:        "UNCLAIMED",
			CreatedAt:     createdAt,
		}

		if h.telegram != nil {
			h.telegram.SendPaymentAlert(txn)
		}
		if h.webhooks != nil {
			h.webhooks.Dispatch("payment.received", txn)
		}
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(models.IngestResponse{
		Success:       true,
		TransactionID: req.TransactionID,
		Status:        status,
	})
}

// Heartbeat records periodic ping from the gateway agent
func (h *GatewayHandler) Heartbeat(w http.ResponseWriter, r *http.Request) {
	gatewayIDVal := r.Context().Value(middleware.GatewayIDContextKey)
	gatewayID, _ := gatewayIDVal.(string)
	if gatewayID == "" {
		gatewayID = r.Header.Get("X-Gateway-ID")
	}

	var req models.HeartbeatRequest
	_ = json.NewDecoder(r.Body).Decode(&req)

	query := `
		UPDATE gateways 
		SET last_heartbeat = NOW(), 
		    is_online = true, 
		    battery_level = CASE WHEN $2 > 0 THEN $2 ELSE battery_level END 
		WHERE id = $1
	`
	_, _ = h.db.ExecContext(r.Context(), query, gatewayID, req.BatteryLevel)

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success":     true,
		"gateway_id":  gatewayID,
		"server_time": time.Now().UTC().Format(time.RFC3339),
	})
}
