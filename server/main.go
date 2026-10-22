package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
	"github.com/birrsync/birrsync-server/internal/config"
	"github.com/birrsync/birrsync-server/internal/database"
	"github.com/birrsync/birrsync-server/internal/handlers"
	"github.com/birrsync/birrsync-server/internal/middleware"
	"github.com/birrsync/birrsync-server/internal/services"
)

func main() {
	cfg := config.LoadConfig()
	log.Printf("[INIT] Starting BirrSync Gateway Server v2.0.0 on port %s", cfg.Port)

	db, err := database.InitDB(cfg)
	if err != nil {
		log.Printf("[DB WARNING] Database connection error: %v. Continuing in degraded mode if DB is spinning up.", err)
	}
	if db != nil {
		defer db.Close()
	}

	tgService := services.NewTelegramService(cfg)
	whService := services.NewWebhookService(db)

	gwHandler := handlers.NewGatewayHandler(db, tgService, whService)
	payHandler := handlers.NewPaymentsHandler(db, tgService, whService)
	adminHandler := handlers.NewAdminHandler(db)

	r := chi.NewRouter()

	// Base Chi middlewares
	r.Use(chimw.RequestID)
	r.Use(chimw.RealIP)
	r.Use(chimw.Logger)
	r.Use(chimw.Recoverer)
	r.Use(chimw.Timeout(30 * time.Second))

	// CORS support for merchant web portals / dashboards
	r.Use(func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Access-Control-Allow-Origin", "*")
			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Gateway-ID, X-Gateway-Timestamp, X-Gateway-Signature, X-App-ID")
			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusOK)
				return
			}
			next.ServeHTTP(w, r)
		})
	})

	// Root / Healthcheck endpoints
	r.Get("/healthz", adminHandler.Health)
	r.Get("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprintf(w, `{"service":"BirrSync Gateway Engine","version":"2.0.0","status":"running","docs":"https://github.com/Samtes64/BirrSync"}`)
	})

	// Public Admin / Inspection APIs
	r.Get("/v1/transactions", adminHandler.ListTransactions)
	r.Get("/v1/gateways", adminHandler.ListGateways)

	// Payment Verification API (called by client mobile apps and web apps)
	r.Route("/v1/payments", func(p chi.Router) {
		p.Post("/verify", payHandler.Verify)
	})

	// Gateway Ingestion Endpoints (HMAC-SHA256 Authenticated)
	r.Route("/v1/gateway", func(g chi.Router) {
		if db != nil {
			g.Use(middleware.HMACAuth(&middleware.DBSecretGetter{DB: db}, cfg.AllowedTimeSkewSecs))
		}
		g.Post("/ingest", gwHandler.Ingest)
		g.Post("/heartbeat", gwHandler.Heartbeat)
	})

	server := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Graceful shutdown channel
	stopChan := make(chan os.Signal, 1)
	signal.Notify(stopChan, os.Interrupt, syscall.SIGTERM)

	go func() {
		log.Printf("[READY] BirrSync Gateway HTTP listening at http://0.0.0.0:%s", cfg.Port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[FATAL] HTTP server failed: %v", err)
		}
	}()

	<-stopChan
	log.Println("[SHUTDOWN] Signal received. Shutting down gracefully...")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer shutdownCancel()

	if err := server.Shutdown(shutdownCtx); err != nil {
		log.Printf("[SHUTDOWN ERROR] Server shutdown failed: %v", err)
	}
	log.Println("[SHUTDOWN] Server exited cleanly.")
}
