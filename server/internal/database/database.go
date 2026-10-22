package database

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/birrsync/birrsync-server/internal/config"
)

// InitDB initializes PostgreSQL connection pool and runs schema migrations
func InitDB(cfg config.Config) (*sql.DB, error) {
	db, err := sql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, fmt.Errorf("failed to open database connection: %w", err)
	}

	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(10)
	db.SetConnMaxLifetime(5 * time.Minute)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := db.PingContext(ctx); err != nil {
		log.Printf("[DB WARNING] Failed to ping database: %v. Running in offline/unmigrated mode if mock.", err)
		return db, err
	}

	log.Println("[DB] Connected to PostgreSQL. Running migrations...")
	if err := Migrate(db, cfg); err != nil {
		return nil, fmt.Errorf("migration failed: %w", err)
	}

	return db, nil
}

// Migrate executes idempotent schema definitions and seeds default credentials
func Migrate(db *sql.DB, cfg config.Config) error {
	schema := `
	CREATE TABLE IF NOT EXISTS gateways (
		id VARCHAR(64) PRIMARY KEY,
		name VARCHAR(128) NOT NULL,
		secret_key VARCHAR(128) NOT NULL,
		last_heartbeat TIMESTAMP WITH TIME ZONE,
		battery_level INT,
		is_online BOOLEAN DEFAULT true,
		created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
	);

	CREATE TABLE IF NOT EXISTS transactions (
		id SERIAL PRIMARY KEY,
		gateway_id VARCHAR(64) REFERENCES gateways(id) ON DELETE SET NULL,
		transaction_id VARCHAR(64) UNIQUE NOT NULL,
		provider VARCHAR(32) NOT NULL,
		amount NUMERIC(12, 2) NOT NULL,
		masked_phone VARCHAR(32),
		phone_suffix VARCHAR(8),
		sender_name VARCHAR(128),
		raw_text TEXT NOT NULL,
		status VARCHAR(20) DEFAULT 'UNCLAIMED',
		claimed_by_app_id VARCHAR(64),
		claimed_by_user_id VARCHAR(64),
		claimed_at TIMESTAMP WITH TIME ZONE,
		created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
	);

	CREATE INDEX IF NOT EXISTS idx_transactions_search ON transactions(phone_suffix, amount, status, created_at);
	CREATE INDEX IF NOT EXISTS idx_transactions_ref ON transactions(transaction_id);
	CREATE INDEX IF NOT EXISTS idx_transactions_created_at ON transactions(created_at);

	CREATE TABLE IF NOT EXISTS webhooks (
		id SERIAL PRIMARY KEY,
		app_id VARCHAR(64) NOT NULL,
		target_url TEXT NOT NULL,
		secret_key VARCHAR(128) NOT NULL,
		is_active BOOLEAN DEFAULT true,
		created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
	);
	`

	if _, err := db.Exec(schema); err != nil {
		return fmt.Errorf("schema execution failed: %w", err)
	}

	// Seed default gateway if provided and table is empty
	if cfg.DefaultGatewayID != "" && cfg.DefaultGatewaySecret != "" {
		seedQuery := `
		INSERT INTO gateways (id, name, secret_key, is_online)
		VALUES ($1, $2, $3, true)
		ON CONFLICT (id) DO NOTHING;
		`
		if _, err := db.Exec(seedQuery, cfg.DefaultGatewayID, "Default Merchant Phone", cfg.DefaultGatewaySecret); err != nil {
			log.Printf("[DB WARNING] Failed to seed default gateway: %v", err)
		} else {
			log.Printf("[DB] Initialized default gateway '%s'", cfg.DefaultGatewayID)
		}
	}

	log.Println("[DB] Schema migrations applied successfully.")
	return nil
}
