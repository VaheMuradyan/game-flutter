package config

import (
	"os"

	"github.com/joho/godotenv"
)

type Config struct {
	DBHost     string
	DBPort     string
	DBUser     string
	DBPassword string
	DBName     string
	JWTSecret  string
	ServerPort string
	UploadDir  string
	Env        string // "development", "staging", "production", "test"
	adminKey   string
}

func (c *Config) AdminKey() string { return c.adminKey }

func Load() *Config {
	env := getEnv("APP_ENV", "development")
	// Load env-specific file first, then plain .env as fallback.
	// godotenv.Load is non-fatal when the file is missing.
	_ = godotenv.Load(".env." + env)
	_ = godotenv.Load(".env")

	return &Config{
		DBHost:     getEnv("DB_HOST", "localhost"),
		DBPort:     getEnv("DB_PORT", "5432"),
		DBUser:     getEnv("DB_USER", "pixelmatch"),
		DBPassword: getEnv("DB_PASSWORD", "pixelmatch_secret_2024"),
		DBName:     getEnv("DB_NAME", "pixelmatch"),
		JWTSecret:  getEnv("JWT_SECRET", "pixelmatch_jwt_secret_change_me"),
		ServerPort: getEnv("SERVER_PORT", "8080"),
		UploadDir:  getEnv("UPLOAD_DIR", "./uploads"),
		Env:        env,
		adminKey:   getEnv("ADMIN_KEY", "dev_admin_key_change_me"),
	}
}

func getEnv(key, fallback string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return fallback
}
