package services

import (
	"bytes"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"time"

	"github.com/birrsync/birrsync-server/internal/config"
	"github.com/birrsync/birrsync-server/internal/models"
)

// TelegramNotifier sends real-time payment alerts to Telegram chat/channel
type TelegramNotifier interface {
	SendPaymentAlert(txn *models.Transaction)
	SendAlert(message string)
}

type TelegramService struct {
	botToken string
	chatID   string
	client   *http.Client
}

func NewTelegramService(cfg config.Config) *TelegramService {
	return &TelegramService{
		botToken: cfg.TelegramBotToken,
		chatID:   cfg.TelegramChatID,
		client: &http.Client{
			Timeout: 5 * time.Second,
		},
	}
}

func (t *TelegramService) SendPaymentAlert(txn *models.Transaction) {
	if t.botToken == "" || t.chatID == "" {
		return
	}

	phoneInfo := ""
	if txn.MaskedPhone != "" {
		phoneInfo = fmt.Sprintf(" (%s)", txn.MaskedPhone)
	}

	senderInfo := "Unknown"
	if txn.SenderName != "" {
		senderInfo = txn.SenderName
	}

	msg := fmt.Sprintf(
		"🔔 *%s Payment Received*\n"+
			"💰 *Amount:* ETB %.2f\n"+
			"👤 *Sender:* %s%s\n"+
			"🔖 *Txn ID:* `%s`\n"+
			"🕒 *Time:* %s",
		txn.Provider,
		txn.Amount,
		senderInfo,
		phoneInfo,
		txn.TransactionID,
		txn.CreatedAt.Format("2006-01-02 15:04:05"),
	)

	go t.send(msg)
}

func (t *TelegramService) SendAlert(message string) {
	if t.botToken == "" || t.chatID == "" {
		return
	}
	go t.send(message)
}

func (t *TelegramService) send(text string) {
	apiURL := fmt.Sprintf("https://api.telegram.org/bot%s/sendMessage", t.botToken)
	payload := map[string]interface{}{
		"chat_id":    t.chatID,
		"text":       text,
		"parse_mode": "Markdown",
	}

	body, err := json.Marshal(payload)
	if err != nil {
		log.Printf("[TELEGRAM] Failed to serialize alert payload: %v", err)
		return
	}

	resp, err := t.client.Post(apiURL, "application/json", bytes.NewBuffer(body))
	if err != nil {
		log.Printf("[TELEGRAM WARNING] Failed to deliver alert: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		log.Printf("[TELEGRAM WARNING] Telegram API returned status %d", resp.StatusCode)
	}
}
