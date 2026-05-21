import Foundation
import SQLite3

struct DatabaseMigrator: Sendable {
    init() {}
    
    func migrate(_ db: SQLiteDatabase) throws {
        // Query user_version
        let getVersionStmt = try db.prepare("PRAGMA user_version;")
        var currentVersion = 0
        if try getVersionStmt.step() {
            currentVersion = getVersionStmt.columnInt(at: 0)
        }
        getVersionStmt.finalize()
        
        if currentVersion < 1 {
            try db.transaction {
                // Table: source_apps
                try db.execute("""
                CREATE TABLE IF NOT EXISTS source_apps (
                    bundle_id       TEXT PRIMARY KEY NOT NULL,
                    app_name        TEXT NOT NULL,
                    icon_cache_path TEXT,
                    last_seen_at    REAL NOT NULL
                );
                """)
                
                // Table: clips
                try db.execute("""
                CREATE TABLE IF NOT EXISTS clips (
                    id                  TEXT PRIMARY KEY NOT NULL,
                    content_hash        TEXT NOT NULL UNIQUE,
                    content_kind        TEXT NOT NULL,
                    first_seen_at       REAL NOT NULL,
                    last_copied_at      REAL NOT NULL,
                    total_copy_count    INTEGER NOT NULL DEFAULT 1,
                    is_pinned           INTEGER NOT NULL DEFAULT 0,
                    pinned_at           REAL,
                    source_app_bundle   TEXT REFERENCES source_apps(bundle_id) ON DELETE SET NULL,
                    payload_hash        TEXT,
                    sync_state          TEXT NOT NULL DEFAULT 'pending'
                );
                """)
                
                // Indices for clips
                try db.execute("""
                CREATE INDEX IF NOT EXISTS idx_clips_content_hash ON clips(content_hash);
                """)
                try db.execute("""
                CREATE INDEX IF NOT EXISTS idx_clips_last_copied_at ON clips(last_copied_at DESC);
                """)
                try db.execute("""
                CREATE INDEX IF NOT EXISTS idx_clips_is_pinned ON clips(is_pinned) WHERE is_pinned = 1;
                """)
                
                // Table: clip_events
                try db.execute("""
                CREATE TABLE IF NOT EXISTS clip_events (
                    event_id            TEXT PRIMARY KEY NOT NULL,
                    clip_id             TEXT NOT NULL REFERENCES clips(id) ON DELETE CASCADE,
                    copied_at           REAL NOT NULL,
                    source_app_bundle   TEXT REFERENCES source_apps(bundle_id) ON DELETE SET NULL
                );
                """)
                
                // Indices for clip_events
                try db.execute("""
                CREATE INDEX IF NOT EXISTS idx_clip_events_copied_at ON clip_events(copied_at DESC);
                """)
                try db.execute("""
                CREATE INDEX IF NOT EXISTS idx_clip_events_clip_id ON clip_events(clip_id);
                """)
                
                // Table: groups
                try db.execute("""
                CREATE TABLE IF NOT EXISTS groups (
                    id          TEXT PRIMARY KEY NOT NULL,
                    name        TEXT NOT NULL,
                    color_tag   TEXT,
                    created_at  REAL NOT NULL
                );
                """)
                
                // Table: clip_groups
                try db.execute("""
                CREATE TABLE IF NOT EXISTS clip_groups (
                    clip_id     TEXT NOT NULL REFERENCES clips(id) ON DELETE CASCADE,
                    group_id    TEXT NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
                    PRIMARY KEY (clip_id, group_id)
                );
                """)
                
                // Table: settings
                try db.execute("""
                CREATE TABLE IF NOT EXISTS settings (
                    id                      TEXT PRIMARY KEY NOT NULL DEFAULT 'settings-v1',
                    max_item_count          INTEGER NOT NULL DEFAULT 2000,
                    ttl_days                INTEGER NOT NULL DEFAULT 30,
                    clear_on_quit           INTEGER NOT NULL DEFAULT 0,
                    excluded_bundle_ids     TEXT NOT NULL DEFAULT '[]',
                    hotkeys_json            TEXT,
                    pause_state_json        TEXT,
                    app_lock_enabled        INTEGER NOT NULL DEFAULT 0,
                    auto_lock_minutes       INTEGER NOT NULL DEFAULT 0,
                    privacy_mode_enabled    INTEGER NOT NULL DEFAULT 0
                );
                """)
                
                // Table: snippets
                try db.execute("""
                CREATE TABLE IF NOT EXISTS snippets (
                    id                      TEXT PRIMARY KEY NOT NULL,
                    title                   TEXT NOT NULL,
                    content_encrypted_path  TEXT,
                    content_kind            TEXT NOT NULL DEFAULT 'text',
                    hotkey_json             TEXT,
                    created_at              REAL NOT NULL,
                    updated_at              REAL NOT NULL,
                    is_pinned               INTEGER NOT NULL DEFAULT 0
                );
                """)
                
                // Virtual Table: clips_fts
                try db.execute("""
                CREATE VIRTUAL TABLE IF NOT EXISTS clips_fts USING fts5(
                    clip_id UNINDEXED,
                    normalized_text,
                    note,
                    tokenize='unicode61 remove_diacritics 2'
                );
                """)
                
                // Set user_version to 1
                try db.execute("PRAGMA user_version = 1;")
            }
        }
    }
}
