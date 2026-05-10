-- @query GetTodo :one
-- @param id: UUID
-- @returns id: UUID, title: String, done: Bool
SELECT id, title, done FROM todos WHERE id = $1;

-- @query ListTodos :many
-- @returns id: UUID, title: String, done: Bool
SELECT id, title, done FROM todos ORDER BY created_at;

-- @query CreateTodo :exec
-- @param id: UUID
-- @param title: String
INSERT INTO todos (id, title) VALUES ($1, $2);

-- @query CompleteTodo :exec
-- @param id: UUID
UPDATE todos SET done = true WHERE id = $1;

-- @query DeleteTodo :exec
-- @param id: UUID
DELETE FROM todos WHERE id = $1;
