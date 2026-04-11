-- Show diagnostics in a floating window
vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float)
-- Move to the previous diagnostic
vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
-- Move to the next diagnostic
vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
-- Show all diagnostics in a location list
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist)
