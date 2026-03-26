return {{
    "neovim/nvim-lspconfig",
    config = function()
        vim.lsp.config("clangd", {
            cmd = {"clangd", "--background-index", "--clang-tidy"}
        })

        vim.lsp.config("rust_analyzer", {
            settings = {
                ["rust-analyzer"] = {
                    checkOnSave = true,
                    check = {
                        command = "clippy"
                    }
                }
            }
        })

        vim.lsp.enable({"clangd", "rust_analyzer"})
    end
}}

