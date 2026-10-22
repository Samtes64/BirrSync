package middleware

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

type mockSecretGetter struct {
	secrets map[string]string
}

func (m *mockSecretGetter) GetGatewaySecret(ctx context.Context, gatewayID string) (string, error) {
	sec, ok := m.secrets[gatewayID]
	if !ok {
		return "", errors.New("gateway not found")
	}
	return sec, nil
}

func TestHMACAuthMiddleware(t *testing.T) {
	getter := &mockSecretGetter{
		secrets: map[string]string{
			"gw_test_1": "super_secret_key_123",
		},
	}

	handler := HMACAuth(getter, 120)(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gw := r.Context().Value(GatewayIDContextKey)
		w.WriteHeader(http.StatusOK)
		w.Write([]byte(fmt.Sprintf("OK: %v", gw)))
	}))

	t.Run("Valid HMAC signature", func(t *testing.T) {
		body := `{"provider":"TELEBIRR","amount":100}`
		now := time.Now().UnixMilli()
		payload := fmt.Sprintf("%d.%s", now, body)
		sig := ComputeHMAC("super_secret_key_123", payload)

		req := httptest.NewRequest("POST", "/v1/gateway/ingest", strings.NewReader(body))
		req.Header.Set("X-Gateway-ID", "gw_test_1")
		req.Header.Set("X-Gateway-Timestamp", fmt.Sprintf("%d", now))
		req.Header.Set("X-Gateway-Signature", sig)

		rr := httptest.NewRecorder()
		handler.ServeHTTP(rr, req)

		if rr.Code != http.StatusOK {
			t.Fatalf("expected status 200, got %d: %s", rr.Code, rr.Body.String())
		}
		if !strings.Contains(rr.Body.String(), "gw_test_1") {
			t.Fatalf("expected body to contain gw_test_1, got %s", rr.Body.String())
		}
	})

	t.Run("Missing headers", func(t *testing.T) {
		req := httptest.NewRequest("POST", "/v1/gateway/ingest", strings.NewReader("{}"))
		rr := httptest.NewRecorder()
		handler.ServeHTTP(rr, req)

		if rr.Code != http.StatusUnauthorized {
			t.Fatalf("expected status 401, got %d", rr.Code)
		}
	})

	t.Run("Timestamp skew expired", func(t *testing.T) {
		body := `{"provider":"TELEBIRR"}`
		expiredTime := time.Now().Add(-5 * time.Minute).UnixMilli()
		payload := fmt.Sprintf("%d.%s", expiredTime, body)
		sig := ComputeHMAC("super_secret_key_123", payload)

		req := httptest.NewRequest("POST", "/v1/gateway/ingest", strings.NewReader(body))
		req.Header.Set("X-Gateway-ID", "gw_test_1")
		req.Header.Set("X-Gateway-Timestamp", fmt.Sprintf("%d", expiredTime))
		req.Header.Set("X-Gateway-Signature", sig)

		rr := httptest.NewRecorder()
		handler.ServeHTTP(rr, req)

		if rr.Code != http.StatusUnauthorized {
			t.Fatalf("expected status 401 for expired timestamp, got %d", rr.Code)
		}
	})

	t.Run("Invalid signature", func(t *testing.T) {
		body := `{"provider":"TELEBIRR"}`
		now := time.Now().UnixMilli()
		req := httptest.NewRequest("POST", "/v1/gateway/ingest", strings.NewReader(body))
		req.Header.Set("X-Gateway-ID", "gw_test_1")
		req.Header.Set("X-Gateway-Timestamp", fmt.Sprintf("%d", now))
		req.Header.Set("X-Gateway-Signature", "deadbeefbadcafe00000000000000000")

		rr := httptest.NewRecorder()
		handler.ServeHTTP(rr, req)

		if rr.Code != http.StatusUnauthorized {
			t.Fatalf("expected status 401 for bad signature, got %d", rr.Code)
		}
	})

	t.Run("Unknown gateway", func(t *testing.T) {
		body := `{"provider":"TELEBIRR"}`
		now := time.Now().UnixMilli()
		payload := fmt.Sprintf("%d.%s", now, body)
		sig := ComputeHMAC("super_secret_key_123", payload)

		req := httptest.NewRequest("POST", "/v1/gateway/ingest", strings.NewReader(body))
		req.Header.Set("X-Gateway-ID", "non_existent_gw")
		req.Header.Set("X-Gateway-Timestamp", fmt.Sprintf("%d", now))
		req.Header.Set("X-Gateway-Signature", sig)

		rr := httptest.NewRecorder()
		handler.ServeHTTP(rr, req)

		if rr.Code != http.StatusUnauthorized {
			t.Fatalf("expected status 401 for unknown gateway, got %d", rr.Code)
		}
	})
}
