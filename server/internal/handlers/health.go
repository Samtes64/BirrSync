package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/birrsync/birrsync-server/internal/models"
)

type AdminHandler struct {
	db *sql.DB
}

func NewAdminHandler(db *sql.DB) *AdminHandler {
	return &AdminHandler{db: db}
}

func (h *AdminHandler) Health(w http.ResponseWriter, r *http.Request) {
	dbStatus := "connected"
	if err := h.db.PingContext(r.Context()); err != nil {
		dbStatus = "unreachable: " + err.Error()
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":    "healthy",
		"service":   "birrsync-gateway",
		"version":   "2.0.0",
		"database":  dbStatus,
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}

func (h *AdminHandler) ListTransactions(w http.ResponseWriter, r *http.Request) {
	limit := 50
	if lStr := r.URL.Query().Get("limit"); lStr != "" {
		if parsed, err := strconv.Atoi(lStr); err == nil && parsed > 0 && parsed <= 200 {
			limit = parsed
		}
	}

	statusFilter := r.URL.Query().Get("status")

	query := `
		SELECT id, gateway_id, transaction_id, provider, amount, masked_phone, phone_suffix,
		       sender_name, raw_text, status, claimed_by_app_id, claimed_by_user_id, claimed_at, created_at
		FROM transactions
	`
	var rows *sql.Rows
	var err error

	if statusFilter != "" {
		query += ` WHERE status = $1 ORDER BY created_at DESC LIMIT $2`
		rows, err = h.db.QueryContext(r.Context(), query, statusFilter, limit)
	} else {
		query += ` ORDER BY created_at DESC LIMIT $1`
		rows, err = h.db.QueryContext(r.Context(), query, limit)
	}

	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}
	defer rows.Close()

	var list []models.Transaction
	for rows.Next() {
		var t models.Transaction
		var claimedApp, claimedUser sql.NullString
		var masked, suffix, sender sql.NullString
		var gwID sql.NullString
		var claimedAt sql.NullTime

		err := rows.Scan(
			&t.ID, &gwID, &t.TransactionID, &t.Provider, &t.Amount, &masked, &suffix,
			&sender, &t.RawText, &t.Status, &claimedApp, &claimedUser, &claimedAt, &t.CreatedAt,
		)
		if err == nil {
			t.GatewayID = gwID.String
			t.MaskedPhone = masked.String
			t.PhoneSuffix = suffix.String
			t.SenderName = sender.String
			if claimedApp.Valid {
				t.ClaimedByAppID = &claimedApp.String
			}
			if claimedUser.Valid {
				t.ClaimedByUserID = &claimedUser.String
			}
			if claimedAt.Valid {
				t.ClaimedAt = &claimedAt.Time
			}
			list = append(list, t)
		}
	}

	if list == nil {
		list = []models.Transaction{}
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(list)
}

func (h *AdminHandler) ListGateways(w http.ResponseWriter, r *http.Request) {
	rows, err := h.db.QueryContext(r.Context(), `
		SELECT id, name, last_heartbeat, battery_level, is_online, created_at 
		FROM gateways 
		ORDER BY created_at ASC
	`)
	if err != nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusInternalServerError)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}
	defer rows.Close()

	var gateways []models.Gateway
	for rows.Next() {
		var g models.Gateway
		var lastHB sql.NullTime
		var batt sql.NullInt32

		err := rows.Scan(&g.ID, &g.Name, &lastHB, &batt, &g.IsOnline, &g.CreatedAt)
		if err == nil {
			if lastHB.Valid {
				g.LastHeartbeat = &lastHB.Time
			}
			if batt.Valid {
				b := int(batt.Int32)
				g.BatteryLevel = &b
			}
			gateways = append(gateways, g)
		}
	}

	if gateways == nil {
		gateways = []models.Gateway{}
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(gateways)
}
