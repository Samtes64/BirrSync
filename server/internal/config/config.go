package config

import (
	"os"
	"strconv"
)

// Config holds runtime configuration loaded from environment variables
type Config struct {
	Port                string
	DatabaseURL         string
	TelegramBotToken    string
	TelegramChatID      string
	AllowedTimeSkewSecs int64
	DefaultGatewayID    string
	DefaultGatewaySecret string
}

// LoadConfig populates Config from environment variables with sensible defaults
func LoadConfig() Config {
	skewSecs, err := strconv.ParseInt(getEnv("ALLOWED_TIME_SKEW_SECS", "120"), 10, 64)
	if err != nil {
		skewSecs = 120
	}

	return Config{
		Port:                getEnv("PORT", "8080"),
		DatabaseURL:         getEnv("DATABASE_URL", "postgres://postgres:password@localhost:5432/birrsync?sslmode=disable"),
		TelegramBotToken:    os.Getenv("TELEGRAM_BOT_TOKEN"),
		TelegramChatID:      os.Getenv("TELEGRAM_CHAT_ID"),
		AllowedTimeSkewSecs: skewSecs,
		DefaultGatewayID:    getEnv("DEFAULT_GATEWAY_ID", "gateway_agent_01"),
		DefaultGatewaySecret: getEnv("DEFAULT_GATEWAY_SECRET", "birrsync_secret_live_key_2026"),
	}
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}
