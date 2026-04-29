-- NovaPay Database Initialization Script
-- Creates the transactions table with indexes

-- Create transactions table
CREATE TABLE IF NOT EXISTS txns (
  id TEXT PRIMARY KEY,
  merchant TEXT NOT NULL,
  amount NUMERIC(10,2) NOT NULL,
  status TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Create indexes for common queries
CREATE INDEX IF NOT EXISTS idx_txns_merchant ON txns(merchant);
CREATE INDEX IF NOT EXISTS idx_txns_status ON txns(status);
CREATE INDEX IF NOT EXISTS idx_txns_created_at ON txns(created_at);

-- Insert sample data for testing
INSERT INTO txns (id, merchant, amount, status) VALUES
  ('test-token-1', 'm_42', 4999, 'AUTHORIZED'),
  ('test-token-2', 'm_42', 9999, 'CAPTURED'),
  ('test-token-3', 'm_99', 1999, 'REFUNDED')
ON CONFLICT (id) DO NOTHING;

-- Display table info
\dt
\d txns
