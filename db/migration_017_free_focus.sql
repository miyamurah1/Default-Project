-- Migration 017: free (unassigned) focus sessions.
--
-- Lets POST /api/focus omit task_id for "Free Deep Work" sessions.
-- Existing rows are untouched; the FK still cascades for task-bound rows.

ALTER TABLE focus_sessions ALTER COLUMN task_id DROP NOT NULL;
