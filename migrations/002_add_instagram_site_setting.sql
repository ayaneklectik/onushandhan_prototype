INSERT INTO site_settings (setting_key, setting_value)
VALUES ('instagram_url', '')
ON CONFLICT (setting_key) DO NOTHING;
