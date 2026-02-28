-- Pin and Paper Supabase Schema v2.0
-- Run in SQL Editor after project creation

-- Tasks
CREATE TABLE tasks (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  title TEXT NOT NULL,
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  parent_id UUID REFERENCES tasks(id) ON DELETE SET NULL,
  position INTEGER NOT NULL DEFAULT 0,
  is_template BOOLEAN NOT NULL DEFAULT FALSE,
  due_date TIMESTAMPTZ,
  is_all_day BOOLEAN DEFAULT TRUE,
  start_date TIMESTAMPTZ,
  notification_type TEXT DEFAULT 'use_global',
  notification_time TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  notes TEXT,
  position_before_completion INTEGER
);

-- Tags
CREATE TABLE tags (
  id UUID PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  name TEXT NOT NULL,
  color TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ,
  UNIQUE(user_id, name)
);

-- Task-Tag junction
CREATE TABLE task_tags (
  task_id UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  tag_id UUID NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (task_id, tag_id)
);

-- Enable RLS on all tables
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_tags ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY tasks_select ON tasks FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY tasks_insert ON tasks FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY tasks_update ON tasks FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY tasks_delete ON tasks FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY tags_select ON tags FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY tags_insert ON tags FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY tags_update ON tags FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY tags_delete ON tags FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY task_tags_select ON task_tags FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY task_tags_insert ON task_tags FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY task_tags_update ON task_tags FOR UPDATE USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY task_tags_delete ON task_tags FOR DELETE USING (auth.uid() = user_id);

-- Auto-update updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tasks_updated_at BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER tags_updated_at BEFORE UPDATE ON tags
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Performance indexes
CREATE INDEX idx_tasks_user_id ON tasks(user_id);
CREATE INDEX idx_tasks_user_active ON tasks(user_id, deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_tasks_user_due ON tasks(user_id, due_date) WHERE due_date IS NOT NULL AND deleted_at IS NULL;
CREATE INDEX idx_tags_user_id ON tags(user_id);
CREATE INDEX idx_task_tags_user ON task_tags(user_id);
