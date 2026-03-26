return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "williamboman/mason.nvim",
    "williamboman/mason-lspconfig.nvim",
  },
  config = function()
    require("mason").setup()
    require("mason-lspconfig").setup({
      ensure_installed = { "clangd" },
    })

    -- 1. Configure the server (Native API)
    -- This merges your custom settings with the defaults from nvim-lspconfig
    vim.lsp.config("clangd", {
      -- Example: custom command or flags
      cmd = { "clangd", "--background-index", "--clang-tidy" },
      -- Add other server-specific settings here
    })

    -- 2. Enable the server
    vim.lsp.enable("clangd")
  end,
}

