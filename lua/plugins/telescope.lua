return {
  'nvim-telescope/telescope.nvim',
  tag = '0.1.8', -- Or use branch = '0.1.x'
  dependencies = { 
    'nvim-lua/plenary.nvim',
    -- Optional: fzf-native for better performance (requires 'make' installed)
    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
  },
  keys = {
    -- Setting these keys triggers lazy-loading the plugin
    { '<leader>ff', '<cmd>Telescope find_files<cr>', desc = 'Find Files' },
    { '<leader>fg', '<cmd>Telescope live_grep<cr>', desc = 'Live Grep' },
    { '<leader>fb', '<cmd>Telescope buffers<cr>', desc = 'Buffers' },
    { '<leader>fh', '<cmd>Telescope help_tags<cr>', desc = 'Help Tags' },
  },
  opts = {
    -- These options are automatically passed to telescope.setup()
    defaults = {
      layout_strategy = "horizontal",
      mappings = {
        i = {
          ["<C-k>"] = "move_selection_previous", -- Standard navigation
          ["<C-j>"] = "move_selection_next",
        },
      },
    },
    extensions = {
      fzf = {} -- Configuration for fzf-native if installed
    }
  },
  config = function(_, opts)
    local telescope = require("telescope")
    telescope.setup(opts)
    -- Load extensions here
    pcall(telescope.load_extension, 'fzf')
  end,
}

