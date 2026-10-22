package models

import (
	"strings"
	"time"
)

// Gateway represents an authorized Flutter mobile gateway device
type Gateway struct {
	ID            string     `json:"id"`
	Name          string     `json:"name"`
	SecretKey     string     `json:"-"`
	LastHeartbeat *time.Time `json:"last_heartbeat"`
	BatteryLevel  *int       `json:"battery_level"`
	IsOnline      bool       `json:"is_online"`
	CreatedAt     time.Time  `json:"created_at"`
}

// IngestRequest represents an intercepted receipt forwarded by the Flutter agent
type IngestRequest struct {
	Provider      string  `json:"provider"`                 // e.g. "TELEBIRR", "CBE"
	TransactionID string  `json:"transaction_id"`          // e.g. "DJD1R7KTJJ"
	Amount        float64 `json:"amount"`                  // e.g. 490.00
	SenderName    string  `json:"sender_name,omitempty"`    // e.g. "Abebe Kebede"
	MaskedPhone   string  `json:"masked_phone,omitempty"`   // e.g. "2519****0720"
	PhoneSuffix   string  `json:"phone_suffix,omitempty"`   // e.g. "0720"
	Raw           string  `json:"raw"`                     // Full SMS body
	DeviceTime    *int64  `json:"device_time,omitempty"`   // Epoch ms reported by device
}

// IngestResponse represents the response back to the Flutter agent
type IngestResponse struct {
	Success       bool   `json:"success"`
	TransactionID string `json:"transaction_id"`
	Status        string `json:"status"` // "recorded" or "already_exists"
}

// HeartbeatRequest payload sent periodically by agent
type HeartbeatRequest struct {
	BatteryLevel int    `json:"battery_level,omitempty"`
	AppVersion   string `json:"app_version,omitempty"`
}

// VerifyRequest sent by merchant backend or client app
type VerifyRequest struct {
	TransactionID  string  `json:"transaction_id,omitempty"`
	SenderPhone    string  `json:"sender_phone,omitempty"`
	ExpectedAmount float64 `json:"expected_amount"`
	MaxAgeMinutes  int     `json:"max_age_minutes,omitempty"`
	AppID          string  `json:"app_id,omitempty"`
	UserID         string  `json:"user_id,omitempty"`
}

// VerifyResponse returned when payment is matched & claimed
type VerifyResponse struct {
	Verified      bool      `json:"verified"`
	TransactionID string    `json:"transaction_id"`
	Provider      string    `json:"provider"`
	Amount        float64   `json:"amount"`
	SenderName    string    `json:"sender_name,omitempty"`
	MaskedPhone   string    `json:"masked_phone,omitempty"`
	PaidAt        time.Time `json:"paid_at"`
	ClaimedAt     time.Time `json:"claimed_at"`
}

// Transaction represents the database row for an intercepted SMS
type Transaction struct {
	ID              int        `json:"id"`
	GatewayID       string     `json:"gateway_id"`
	TransactionID   string     `json:"transaction_id"`
	Provider        string     `json:"provider"`
	Amount          float64    `json:"amount"`
	MaskedPhone     string     `json:"masked_phone,omitempty"`
	PhoneSuffix     string     `json:"phone_suffix,omitempty"`
	SenderName      string     `json:"sender_name,omitempty"`
	RawText         string     `json:"raw_text"`
	Status          string     `json:"status"` // "UNCLAIMED", "CLAIMED", "EXPIRED"
	ClaimedByAppID  *string    `json:"claimed_by_app_id,omitempty"`
	ClaimedByUserID *string    `json:"claimed_by_user_id,omitempty"`
	ClaimedAt       *time.Time `json:"claimed_at,omitempty"`
	CreatedAt       time.Time  `json:"created_at"`
}

// Webhook payload dispatched to third-party endpoints
type WebhookPayload struct {
	Event         string    `json:"event"` // "payment.received", "payment.verified"
	TransactionID string    `json:"transaction_id"`
	Provider      string    `json:"provider"`
	Amount        float64   `json:"amount"`
	SenderName    string    `json:"sender_name,omitempty"`
	MaskedPhone   string    `json:"masked_phone,omitempty"`
	Timestamp     time.Time `json:"timestamp"`
}

// CleanTransactionID normalizes transaction ID by stripping URLs (e.g. CBE receipt links) and uppercasing
func CleanTransactionID(input string) string {
	trimmed := strings.TrimSpace(input)
	if trimmed == "" {
		return ""
	}
	// If input is a URL like https://mbreciept.cbe.com.et/v2-hfHCxHC6unkKSXCtrNI1
	if strings.Contains(trimmed, "/") {
		parts := strings.Split(trimmed, "/")
		for i := len(parts) - 1; i >= 0; i-- {
			if strings.TrimSpace(parts[i]) != "" {
				trimmed = strings.TrimSpace(parts[i])
				break
			}
		}
	}
	// Strip query params or fragment
	if idx := strings.IndexAny(trimmed, "?#"); idx != -1 {
		trimmed = trimmed[:idx]
	}
	return strings.ToUpper(trimmed)
}

