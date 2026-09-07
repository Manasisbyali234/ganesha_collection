-- =========================================================
-- Temple / Trust Collection Management - PostgreSQL Schema
-- =========================================================

DROP TABLE IF EXISTS meeting_items CASCADE;
DROP TABLE IF EXISTS meetings CASCADE;
DROP TABLE IF EXISTS sankalp_bookings CASCADE;
DROP TABLE IF EXISTS pooja_bookings CASCADE;
DROP TABLE IF EXISTS banners CASCADE;
DROP TABLE IF EXISTS donations CASCADE;
DROP TABLE IF EXISTS devotees CASCADE;
DROP TABLE IF EXISTS members CASCADE;
DROP TABLE IF EXISTS admins CASCADE;

-- ---------------------------------------------------------
-- Admins (super users who create members/staff accounts)
-- ---------------------------------------------------------
CREATE TABLE admins (
    id            SERIAL PRIMARY KEY,
    name          VARCHAR(120) NOT NULL,
    email         VARCHAR(150) UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at    TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------
-- Members (collection agents/volunteers) - created by admin
-- ---------------------------------------------------------
CREATE TABLE members (
    id              SERIAL PRIMARY KEY,
    name            VARCHAR(120) NOT NULL,
    email           VARCHAR(150) UNIQUE NOT NULL,
    phone           VARCHAR(20) NOT NULL,
    password_hash   TEXT NOT NULL,
    status          VARCHAR(20) NOT NULL DEFAULT 'active', -- active / inactive
    created_by      INTEGER REFERENCES admins(id) ON DELETE SET NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------
-- Devotees ("Add User" from the member dashboard) - the
-- people a member registers, with an initial payment
-- ---------------------------------------------------------
CREATE TABLE devotees (
    id                SERIAL PRIMARY KEY,
    member_id         INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    name              VARCHAR(120) NOT NULL,
    address           TEXT,
    phone             VARCHAR(20),
    initial_payment   NUMERIC(12,2) NOT NULL DEFAULT 0,
    payment_method    VARCHAR(20) NOT NULL DEFAULT 'cash', -- cash / phone / card / upi / bank / other
    total_amount      NUMERIC(12,2) NOT NULL DEFAULT 0,     -- total pledged/expected amount
    paid_amount       NUMERIC(12,2) NOT NULL DEFAULT 0,     -- running total actually paid (incl. initial payment)
    outstanding_amount NUMERIC(12,2) GENERATED ALWAYS AS (GREATEST(total_amount - paid_amount, 0)) STORED,
    status            VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending / partially_paid / paid
    created_at        TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------
-- Donations - Gold / Silver / Food / Cash / Other sections
-- ---------------------------------------------------------
CREATE TABLE donations (
    id              SERIAL PRIMARY KEY,
    member_id       INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    devotee_id      INTEGER REFERENCES devotees(id) ON DELETE SET NULL,
    donor_name      VARCHAR(120) NOT NULL,
    donor_phone     VARCHAR(20),
    section         VARCHAR(30) NOT NULL,   -- gold / silver / food / cash / other
    description     TEXT,                   -- e.g. "1 gold ring - 5gm"
    amount          NUMERIC(12,2) NOT NULL DEFAULT 0,
    payment_method  VARCHAR(20) NOT NULL DEFAULT 'cash',
    paid            BOOLEAN NOT NULL DEFAULT true,
    donation_date   DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------
-- Banners / Advertisements
-- ---------------------------------------------------------
CREATE TABLE banners (
    id          SERIAL PRIMARY KEY,
    member_id   INTEGER REFERENCES members(id) ON DELETE SET NULL,
    title       VARCHAR(150) NOT NULL,
    image_url   TEXT,
    description TEXT,
    start_date  DATE NOT NULL,
    end_date    DATE NOT NULL,
    start_time  TIME,
    end_time    TIME,
    active      BOOLEAN NOT NULL DEFAULT true,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------
-- Pooja Booking
-- ---------------------------------------------------------
CREATE TABLE pooja_bookings (
    id            SERIAL PRIMARY KEY,
    member_id     INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    devotee_name  VARCHAR(120) NOT NULL,
    phone         VARCHAR(20),
    pooja_name    VARCHAR(120) NOT NULL,
    booking_date  DATE NOT NULL,
    booking_time  TIME,
    amount        NUMERIC(12,2) NOT NULL DEFAULT 0,
    payment_method VARCHAR(20) NOT NULL DEFAULT 'cash',
    status        VARCHAR(20) NOT NULL DEFAULT 'booked', -- booked / completed / cancelled
    created_at    TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------
-- Ana Sankalp Booking
-- ---------------------------------------------------------
CREATE TABLE sankalp_bookings (
    id            SERIAL PRIMARY KEY,
    member_id     INTEGER NOT NULL REFERENCES members(id) ON DELETE CASCADE,
    devotee_name  VARCHAR(120) NOT NULL,
    phone         VARCHAR(20),
    sankalp_type  VARCHAR(120) NOT NULL,
    booking_date  DATE NOT NULL,
    booking_time  TIME,
    amount        NUMERIC(12,2) NOT NULL DEFAULT 0,
    payment_method VARCHAR(20) NOT NULL DEFAULT 'cash',
    status        VARCHAR(20) NOT NULL DEFAULT 'booked',
    created_at    TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ---------------------------------------------------------
-- Meetings (Sawal) with required items
-- ---------------------------------------------------------
CREATE TABLE meetings (
    id          SERIAL PRIMARY KEY,
    member_id   INTEGER REFERENCES members(id) ON DELETE SET NULL,
    title       VARCHAR(150) NOT NULL,
    meeting_date DATE NOT NULL,
    meeting_time TIME,
    notes       TEXT,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE meeting_items (
    id          SERIAL PRIMARY KEY,
    meeting_id  INTEGER NOT NULL REFERENCES meetings(id) ON DELETE CASCADE,
    item_name   VARCHAR(150) NOT NULL,
    item_type   VARCHAR(80),
    quantity    VARCHAR(50),
    notes       TEXT
);

-- Helpful indexes
CREATE INDEX idx_devotees_member ON devotees(member_id);
CREATE INDEX idx_donations_member ON donations(member_id);
CREATE INDEX idx_pooja_member ON pooja_bookings(member_id);
CREATE INDEX idx_sankalp_member ON sankalp_bookings(member_id);
CREATE INDEX idx_meetings_member ON meetings(member_id);

-- Seed a default admin: email admin@temple.com / password Admin@123
-- (password_hash below is a bcrypt hash generated by the backend seed script,
--  see src/seed.js - do NOT hardcode plaintext in production)
