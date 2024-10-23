#!/bin/bash
#
# Script Name: init.sh
# Author: Inge Gatovsky
# Date: 23/10/24

set -euo pipefail

DB_PASSWORD=$(cat /run/secrets/db_password)
POSTGRES_PASSWORD=$(cat /run/secrets/postgres-passwd)
DB_USER=${DB_USER:-}
DB_NAME=${DB_NAME:-}

echo "DB_USER: $DB_USER"
echo "DB_NAME: $DB_NAME"
echo "DB_PASSWORD: $DB_PASSWORD"
echo "POSTGRES_PASSWORD: $POSTGRES_PASSWORD"

# check if the variables are empty
if [ -z "$POSTGRES_PASSWORD" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ]; then
    echo "Usage: $0 POSTGRES_PASSWORD DB_PASSWORD DB_NAME DB_USER"
    exit 1
fi

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER "$DB_USER" WITH PASSWORD '$DB_PASSWORD';
    DROP DATABASE IF EXISTS "$DB_NAME" WITH (FORCE);
    CREATE DATABASE "$DB_NAME" 
    WITH 
        OWNER = "$DB_USER" 
        ENCODING = 'UTF8' 
        TABLESPACE = pg_default 
        CONNECTION LIMIT = -1;
EOSQL


psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB_NAME" <<-EOSQL
    SET timezone = 'America/Denver'; -- UTC-7

    CREATE TABLE users (
        IdUser SERIAL PRIMARY KEY,
        Name VARCHAR(100) NOT NULL,
        Password BYTEA NOT NULL,
        Email VARCHAR(100) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE roles (
            IdRole SERIAL PRIMARY KEY,
            Name VARCHAR(50) UNIQUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

    CREATE TABLE user_roles (
            IdUserRole SERIAL PRIMARY KEY,
            IdUser INT NOT NULL,
            IdRole INT NOT NULL,
            CONSTRAINT fk_user 
                FOREIGN KEY(IdUser) 
                REFERENCES users(IdUser)
                ON DELETE CASCADE,
            CONSTRAINT fk_role 
                FOREIGN KEY(IdRole) 
                REFERENCES roles(IdRole)
                ON DELETE CASCADE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

    CREATE TABLE address (
            IdAddress SERIAL PRIMARY KEY,
            Street VARCHAR(100) NOT NULL,
            Number INT NOT NULL,
            City VARCHAR(100) NOT NULL,
            State VARCHAR(100) NOT NULL,
            Country VARCHAR(100) NOT NULL,
            PostalCode VARCHAR(10) NOT NULL,
            UrlMaps VARCHAR(255) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

    CREATE TABLE restaurants (
            IdRestaurant SERIAL PRIMARY KEY,
            IdAddress INT NOT NULL,
            Name VARCHAR(100) NOT NULL,
            Phone VARCHAR(20) NOT NULL,
            UrlImage VARCHAR(255),
            CONSTRAINT fk_address 
                FOREIGN KEY(IdAddress) 
                REFERENCES address(IdAddress)
                ON DELETE SET NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

    CREATE TABLE menus (
            IdMenu SERIAL PRIMARY KEY,
            IdRestaurant INT NOT NULL,
            Name VARCHAR(100) NOT NULL,
            Description TEXT NOT NULL,
            Price DECIMAL(10,2) NOT NULL,
            UrlImage VARCHAR(255),
            CONSTRAINT fk_restaurant 
                FOREIGN KEY(IdRestaurant) 
                REFERENCES restaurants(IdRestaurant)
                ON DELETE CASCADE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

    CREATE TABLE days (
            IdDay SERIAL PRIMARY KEY,
            Name VARCHAR(10) UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

    CREATE TABLE schedules (
            IdSchedule SERIAL PRIMARY KEY,
            IdRestaurant INT NOT NULL,
            IdDay INT NOT NULL,
            OpenTime TIME NOT NULL,
            CloseTime TIME NOT NULL,
            CONSTRAINT fk_restaurant_schedule 
                FOREIGN KEY(IdRestaurant) 
                REFERENCES restaurants(IdRestaurant)
                ON DELETE CASCADE,
            CONSTRAINT fk_day_schedule
                FOREIGN KEY(IdDay)
                REFERENCES days(IdDay)
                ON DELETE CASCADE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

    CREATE TABLE categories (
            IdCategory SERIAL PRIMARY KEY,
            Name VARCHAR(100) UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

    CREATE TABLE restaurent_categories (
            IdRestaurantCategory SERIAL PRIMARY KEY,
            IdRestaurant INT NOT NULL,
            IdCategory INT NOT NULL,
            CONSTRAINT fk_restaurant_category 
                FOREIGN KEY(IdRestaurant) 
                REFERENCES restaurants(IdRestaurant)
                ON DELETE CASCADE,
            CONSTRAINT fk_category 
                FOREIGN KEY(IdCategory) 
                REFERENCES categories(IdCategory)
                ON DELETE CASCADE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

    CREATE TABLE review (
            IdReview SERIAL PRIMARY KEY,
            IdUser INT NULL,
            IdRestaurant INT NOT NULL,
            Rating INT NOT NULL CHECK (Rating BETWEEN 1 AND 5),
            Comment TEXT NOT NULL,
            DateReview DATE NOT NULL,
            CONSTRAINT fk_user_review 
                FOREIGN KEY(IdUser) 
                REFERENCES users(IdUser)
                ON DELETE SET NULL,
            CONSTRAINT fk_restaurant_review 
                FOREIGN KEY(IdRestaurant) 
                REFERENCES restaurants(IdRestaurant)
                ON DELETE CASCADE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );

    -- Indexes
    CREATE INDEX idx_menu_name ON menus(Name);
    CREATE INDEX idx_restaurant_category ON restaurent_categories(IdCategory, IdRestaurant);
    CREATE INDEX idx_review_comment ON review USING gin (TO_TSVECTOR('spanish', Comment));

    -- Views
    CREATE VIEW vw_restaurant_menu AS
        SELECT 
            r.IdRestaurant,
            r.Name AS RestaurantName,
            m.IdMenu,
            m.Name AS MenuName,
            m.Description,
            m.Price,
            m.UrlImage
        FROM restaurants r
        JOIN menus m ON r.IdRestaurant = m.IdRestaurant;

    CREATE VIEW vw_restaurant_info AS
        SELECT 
            r.Name AS RestaurantName,
            r.Phone,
            r.UrlImage,
            c.Name AS CategoryName,
            a.Street,
            a.Number,
            a.City,
            a.UrlMaps
        FROM restaurants r
        JOIN restaurent_categories rc ON r.IdRestaurant = rc.IdRestaurant
        JOIN categories c ON rc.IdCategory = c.IdCategory
        JOIN address a ON r.IdAddress = a.IdAddress;

    -- MATTERIALIZED VIEWS

    CREATE MATERIALIZED VIEW mv_restaurant_rating AS
        SELECT 
            r.IdRestaurant,
            r.Name AS RestaurantName,
            AVG(rv.Rating) AS Rating,
            COUNT(rv.IdReview) AS TotalReviews
        FROM restaurants r
        JOIN review rv ON r.IdRestaurant = rv.IdRestaurant
        GROUP BY r.IdRestaurant, r.Name;

    --REFRESH MATERIALIZED VIEW mv_restaurant_rating;

    -- INSERTS
    INSERT INTO days (Name) VALUES 
        ('Lunes'), ('Martes'), ('Miércoles'), 
        ('Jueves'), ('Viernes'), ('Sábado'), ('Domingo');
    INSERT INTO roles (Name) VALUES 
        ('Admin'), ('User');
    INSERT INTO categories (Name) VALUES 
        ('Rápida'), ('China'), ('Mexicana'), ('Italiana'), 
        ('Japonesa'), ('Desayunos'), ('Cafetería'), ('Postres'), 
        ('Vegetariana'), ('Vegana'), ('Carnes'), ('Mariscos');
EOSQL

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$DB_NAME" <<-EOSQL
    -- Grant permissions on existing tables
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "$DB_USER";

    -- Grant permissions on sequences
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO "$DB_USER";

     -- Grant permissions on existing views
    DO \$\$
    BEGIN
        PERFORM format('GRANT SELECT ON %I.%I TO %I;',
            schemaname, viewname, '$DB_USER')
        FROM pg_views 
        WHERE schemaname = 'public';
    END
    \$\$;

    -- Grant permissions on existing materialized views
    DO \$\$
    BEGIN
        PERFORM format('GRANT SELECT ON %I.%I TO %I;',
            schemaname, matviewname, '$DB_USER')
        FROM pg_matviews
        WHERE schemaname = 'public';
    END
    \$\$;

    -- Set default privileges for future tables
    ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "$DB_USER";

    -- Ensure user has only necessary access
    REVOKE ALL PRIVILEGES ON DATABASE "$POSTGRES_DB" FROM PUBLIC;
    GRANT CONNECT ON DATABASE "$DB_NAME" TO "$DB_USER";
EOSQL
