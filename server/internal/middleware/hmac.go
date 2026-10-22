package middleware

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"fmt"
	"io"
	"math"
	"net/http"
	"strconv"
	"time"
)

type contextKey string

const GatewayIDContextKey contextKey = "gateway_id"

// GatewaySecretGetter interface abstracts gateway secret retrieval (useful for testing & DB)
type GatewaySecretGetter interface {
	GetGatewaySecret(ctx context.Context, gatewayID string) (string, error)
}

// DBSecretGetter implements GatewaySecretGetter via *sql.DB
type DBSecretGetter struct {
	DB *sql.DB
}

func (s *DBSecretGetter) GetGatewaySecret(ctx context.Context, gatewayID string) (string, error) {
	var secretKey string
	err := s.DB.QueryRowContext(ctx, "SELECT secret_key FROM gateways WHERE id = $1", gatewayID).Scan(&secretKey)
	if err != nil {
		return "", err
	}
	return secretKey, nil
}

// ComputeHMAC calculates HMAC-SHA256 hex string for timestamp.body
func ComputeHMAC(secret, payload string) string {
	h := hmac.New(sha256.New, []byte(secret))
	h.Write([]byte(payload))
	return hex.EncodeToString(h.Sum(nil))
}

// HMACAuth creates middleware verifying HMAC-SHA256 signatures from gateway agents
func HMACAuth(getter GatewaySecretGetter, allowedSkewSeconds int64) func(http.Handler) http.Handler {
	if allowedSkewSeconds <= 0 {
		allowedSkewSeconds = 120
	}
	maxSkewMs := float64(allowedSkewSeconds * 1000)

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			gatewayID := r.Header.Get("X-Gateway-ID")
			tsStr := r.Header.Get("X-Gateway-Timestamp")
			signature := r.Header.Get("X-Gateway-Signature")

			if gatewayID == "" || tsStr == "" || signature == "" {
				http.Error(w, `{"error":"Missing authentication headers (X-Gateway-ID, X-Gateway-Timestamp, X-Gateway-Signature)"}`, http.StatusUnauthorized)
				return
			}

			ts, err := strconv.ParseInt(tsStr, 10, 64)
			if err != nil {
				http.Error(w, `{"error":"Malformed X-Gateway-Timestamp header"}`, http.StatusUnauthorized)
				return
			}

			nowMs := time.Now().UnixMilli()
			if math.Abs(float64(nowMs-ts)) > maxSkewMs {
				http.Error(w, `{"error":"Request expired or clock skewed beyond acceptable threshold"}`, http.StatusUnauthorized)
				return
			}

			secretKey, err := getter.GetGatewaySecret(r.Context(), gatewayID)
			if err != nil {
				http.Error(w, `{"error":"Unknown or unauthorized gateway ID"}`, http.StatusUnauthorized)
				return
			}

			bodyBytes, err := io.ReadAll(r.Body)
			if err != nil {
				http.Error(w, `{"error":"Unable to read request payload"}`, http.StatusBadRequest)
				return
			}
			// Restore request body for downstream handlers
			r.Body = io.NopCloser(bytes.NewBuffer(bodyBytes))

			payloadToSign := fmt.Sprintf("%d.%s", ts, string(bodyBytes))
			expectedSig := ComputeHMAC(secretKey, payloadToSign)

			if !hmac.Equal([]byte(signature), []byte(expectedSig)) {
				http.Error(w, `{"error":"Invalid gateway signature"}`, http.StatusUnauthorized)
				return
			}

			// Attach gateway ID to context
			ctx := context.WithValue(r.Context(), GatewayIDContextKey, gatewayID)
			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}
