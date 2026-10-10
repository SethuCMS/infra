-- Sample customer database for local testing. Throwaway data only.
CREATE TABLE customers (
  id          serial PRIMARY KEY,
  email       text NOT NULL UNIQUE,
  full_name   text NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE orders (
  id           serial PRIMARY KEY,
  customer_id  integer NOT NULL REFERENCES customers(id),
  status       text NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'paid', 'shipped', 'cancelled')),
  total_cents  integer NOT NULL CHECK (total_cents >= 0),
  created_at   timestamptz NOT NULL DEFAULT now()
);

INSERT INTO customers (email, full_name) VALUES
  ('ada@example.com', 'Ada Example'),
  ('grace@example.com', 'Grace Example'),
  ('linus@example.com', 'Linus Example');

INSERT INTO orders (customer_id, status, total_cents) VALUES
  (1, 'paid', 4200), (1, 'new', 1300), (2, 'shipped', 9900), (3, 'cancelled', 500), (3, 'paid', 2750);

-- A read-only login for connecting the CMS in read-only mode.
-- The password below is for this throwaway container only.
CREATE ROLE cms_reader LOGIN PASSWORD 'local-reader-only';
GRANT CONNECT ON DATABASE shop TO cms_reader;
GRANT USAGE ON SCHEMA public TO cms_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO cms_reader;
ALTER ROLE cms_reader SET default_transaction_read_only = on;
