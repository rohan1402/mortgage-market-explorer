-- Reference data: HMDA code lookups and New Jersey counties.
-- Codes follow the FFIEC public LAR data dictionary.
SET search_path TO mme;

INSERT INTO action_taken_code VALUES
  (1, 'Loan originated'),
  (2, 'Application approved but not accepted'),
  (3, 'Application denied'),
  (4, 'Application withdrawn by applicant'),
  (5, 'File closed for incompleteness'),
  (6, 'Purchased loan'),                 -- dropped at load (D16)
  (7, 'Preapproval request denied'),
  (8, 'Preapproval request approved but not accepted');

INSERT INTO loan_type_code VALUES
  (1, 'Conventional'),
  (2, 'FHA'),
  (3, 'VA'),
  (4, 'USDA RHS/FSA');

INSERT INTO loan_purpose_code VALUES
  (1,  'Home purchase'),
  (2,  'Home improvement'),
  (31, 'Refinancing'),
  (32, 'Cash-out refinancing'),
  (4,  'Other purpose'),
  (5,  'Not applicable');

INSERT INTO occupancy_code VALUES
  (1, 'Principal residence'),
  (2, 'Second residence'),
  (3, 'Investment property');

INSERT INTO denial_reason_code VALUES
  (1, 'Debt-to-income ratio'),
  (2, 'Employment history'),
  (3, 'Credit history'),
  (4, 'Collateral'),
  (5, 'Insufficient cash (downpayment, closing costs)'),
  (6, 'Unverifiable information'),
  (7, 'Credit application incomplete'),
  (8, 'Mortgage insurance denied'),
  (9, 'Other');

-- HMDA publishes DTI in bins; 36..49 are single percentages.
INSERT INTO dti_bucket_code VALUES (1, '<20%'), (2, '20%-<30%'), (3, '30%-<36%');
INSERT INTO dti_bucket_code SELECT g, g || '%' FROM generate_series(36, 49) g;
INSERT INTO dti_bucket_code VALUES (50, '50%-60%'), (61, '>60%');

-- county_id is the 3-digit county code (34023 Middlesex -> 23), see db/schema.sql.
INSERT INTO county (county_id, county_fips, name, state_code)
SELECT right(fips, 3)::smallint, fips, name, 'NJ'
FROM (VALUES
  ('34001', 'Atlantic'),   ('34003', 'Bergen'),     ('34005', 'Burlington'),
  ('34007', 'Camden'),     ('34009', 'Cape May'),   ('34011', 'Cumberland'),
  ('34013', 'Essex'),      ('34015', 'Gloucester'), ('34017', 'Hudson'),
  ('34019', 'Hunterdon'),  ('34021', 'Mercer'),     ('34023', 'Middlesex'),
  ('34025', 'Monmouth'),   ('34027', 'Morris'),     ('34029', 'Ocean'),
  ('34031', 'Passaic'),    ('34033', 'Salem'),      ('34035', 'Somerset'),
  ('34037', 'Sussex'),     ('34039', 'Union'),      ('34041', 'Warren')
) AS nj (fips, name);

-- Parses HMDA numeric text; 'NA', 'Exempt' and blanks become NULL.
CREATE FUNCTION num(t text) RETURNS numeric
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE WHEN t ~ '^-?[0-9]+(\.[0-9]+)?$' THEN t::numeric END
$$;
