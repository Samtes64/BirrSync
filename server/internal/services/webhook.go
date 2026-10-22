package services

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"log"
	"net/http"
	"time"

	"github.com/birrsync/birrsync-server/internal/models"
)

type WebhookDispatcher interface {
	Dispatch(event string, txn *models.Transaction)
}

type WebhookService struct {
	db     *sql.DB
	client *http.Client
}

func NewWebhookService(db *sql.DB) *WebhookService {
	return &WebhookService{
		db: db,
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

type targetHook struct {
	ID        int
	AppID     string
	TargetURL string
	SecretKey string
}

func (w *WebhookService) Dispatch(event string, txn *models.Transaction) {
	if w.db == nil {
		return
	}

	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()

		rows, err := w.db.QueryContext(ctx, "SELECT id, app_id, target_url, secret_key FROM webhooks WHERE is_active = true")
		if err != nil {
			log.Printf("[WEBHOOK WARNING] Failed to query active webhooks: %v", err)
			return
		}
		defer rows.Close()

		var hooks []targetHook
		for rows.Next() {
			var h targetHook
			if err := rows.Scan(&h.ID, &h.AppID, &h.TargetURL, &h.SecretKey); err == nil {
				hooks = append(hooks, h)
			}
		}

		payload := models.WebhookPayload{
			Event:         event,
			TransactionID: txn.TransactionID,
			Provider:      txn.Provider,
			Amount:        txn.Amount,
			SenderName:    txn.SenderName,
			MaskedPhone:   txn.MaskedPhone,
			Timestamp:     time.Now().UTC(),
		}

		bodyBytes, err := json.Marshal(payload)
		if err != nil {
			log.Printf("[WEBHOOK] Serialization failed: %v", err)
			return
		}

		for _, hook := range hooks {
			w.deliver(hook, bodyBytes)
		}
	}()
}

func (w *WebhookService) deliver(hook targetHook, body []byte) {
	req, err := http.NewRequest("POST", hook.TargetURL, bytes.NewBuffer(body))
	if err != nil {
		log.Printf("[WEBHOOK] Malformed URL %s: %v", hook.TargetURL, err)
		return
	}

	h := hmac.New(sha256.New, []byte(hook.SecretKey))
	h.Write(body)
	sig := hex.EncodeToString(h.Sum(nil))

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("User-Agent", "BirrSync-Gateway-Webhook/2.0")
	req.Header.Set("X-BirrSync-Signature", sig)
	req.Header.Set("X-BirrSync-App", hook.AppID)

	resp, err := w.client.Do(req)
	if err != nil {
		log.Printf("[WEBHOOK DELIVER ERROR] %s: %v", hook.TargetURL, err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		log.Printf("[WEBHOOK DELIVER WARNING] %s returned status %d", hook.TargetURL, resp.StatusCode)
	}
}
