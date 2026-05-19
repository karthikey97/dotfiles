vim.opt.laststatus = 0
vim.opt.showtabline = 2

-- 1. BOOTSTRAP LAZY.NVIM
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Enable fuzzy case sensitive search accross the root dir
vim.opt.path:append("**")
vim.opt.wildignorecase = true
vim.opt.wildignore:append({ "**/data/*", "**/work_dir/*", "**/__pycache__/*", "**/*errs/*", "**/*outs*/*", "**/.git/*"})

--  Text-highlighting on cursor hover
vim.opt.updatetime = 300
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if client.server_capabilities.documentHighlightProvider then
      vim.cmd([[
        augroup lsp_document_highlight
          autocmd! * <buffer>
          autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
          autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
        augroup END
      ]])
    end
  end,
})

-- switch buffers with Tab and S+Tab
vim.api.nvim_set_keymap('n', '<Tab>', ':bnext<CR>', { noremap = true, silent = true, desc = "Next buffer" })
vim.api.nvim_set_keymap('n', '<S-Tab>', ':bprevious<CR>', { noremap = true, silent = true, desc = "Previous buffer" })

-- 2. PLUGIN SPECS
require("lazy").setup({
  -- === THEME: ONEDARK (Transparent) ===
  {
    "navarasu/onedark.nvim",
    lazy = false,
    priority = 1000,
    config = function()
      require('onedark').setup {
        style = 'dark',       -- Standard vibrant colors
        transparent = true,   -- <--- KEY: KEEPS YOUR TERMINAL BACKGROUND
        term_colors = true,   -- Use terminal colors for better compatibility
        code_style = {
          comments = 'italic',
          keywords = 'bold',
          functions = 'none',
          strings = 'none',
          variables = 'none'
        },
      }
      require('onedark').load()
    end,
  },
  
  -- === TELESCOPE (Search) ===
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    tag = "0.1.5",
    config = function()
      require('telescope').setup({
        defaults = {
          file_ignore_patterns = { 
            "%.obj", "%.ply", "%.pt", "%.npy", "%.log", "%.txt", "%.err", "%.out",
            "node_modules", ".git/" 
          },
          mappings = {
            i = { ["<C-u>"] = false, ["<C-d>"] = false },
          },
        },
      })
      local builtin = require('telescope.builtin')
      vim.keymap.set('n', '<leader>f', builtin.find_files, {})
      vim.keymap.set('n', '<leader>g', builtin.live_grep, {})
      vim.keymap.set('n', '<leader>b', builtin.buffers, {})
    end
  },

  -- === TREESITTER (Syntax Highlighting) ===
  {
    "nvim-treesitter/nvim-treesitter",
    lazy=false,
    version = "*", -- Pin to stable
    build = ":TSUpdate",
    config = function()
      local status, configs = pcall(require, "nvim-treesitter.configs")
      if not status then return end

      configs.setup({
        ensure_installed = { "python", "json", "yaml", "lua" },
        -- This 'highlight' block is what gives you better colors
        -- WITHOUT changing the background
        highlight = { enable = true },
        indent = { enable = true },
      })
    end
  },

  -- === INDENT NAVIGATION === --
  {
    "jessekelighine/vindent.nvim",
    config = function()
    local vindent = require("vindent")
    local block_opts = {
    strict = { 	
	skip_empty_lines = false, skip_more_indented_lines = false },
	contiguous = { skip_empty_lines = false, skip_more_indented_lines = true  },
	loose      = { skip_empty_lines = true,  skip_more_indented_lines = true  },
    }
    vindent.map.BlockMotion({ prev = "[i", next = "]i" }, block_opts.strict)
    vindent.map.Motion({ prev = "[h", next = "]h" }, "less")
    vindent.map.Motion({ prev = "[l", next = "]l" }, "more")
    vim.g.vindent_begin = false
    end
  },

  -- === AUTOBRACKET === --
  {
    "m4xshen/autoclose.nvim",
    config = function()
    require("autoclose").setup()
    end
  },

  -- === AUTOCOMPLETE (CMP) ===
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
    },
    config = function()
      local cmp = require('cmp')
      cmp.setup({
        snippet = {
          expand = function(args) require('luasnip').lsp_expand(args.body) end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'path' },
        })
      })
    end
  },

  -- === LSP (Language Server) ===
  {
    "neovim/nvim-lspconfig",
    tag = "v0.1.7", -- Pinned to keep it silent
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    config = function()
      local status, lspconfig = pcall(require, "lspconfig")
      if not status then return end

      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      -- Pyright
      lspconfig.pyright.setup({
        capabilities = capabilities,
        settings = {
          python = {
            analysis = {
              typeCheckingMode = "basic",
              autoSearchPaths = true,
              useLibraryCodeForTypes = true
            }
          }
        }
      })
      
      -- Other Servers
      lspconfig.jsonls.setup({ capabilities = capabilities })
      lspconfig.yamlls.setup({ capabilities = capabilities })

    -- Keymaps
      vim.api.nvim_create_autocmd('LspAttach', {
        callback = function(ev)
          local opts = { buffer = ev.buf }
          local telescope_builtin = require('telescope.builtin')

          -- === UPDATED NAVIGATION (Uses Telescope) ===
          -- If multiple definitions exist, this opens a nice Telescope list.
          -- Press ESC to close it.
          vim.keymap.set('n', 'gd', telescope_builtin.lsp_definitions, opts)
          vim.keymap.set('n', 'gr', telescope_builtin.lsp_references, opts)

          -- Standard LSP maps (Keep these)
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
          vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)

          -- Diagnostics (Error messages)
          vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, opts)
          vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
          vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
        end,
      })
    end
  }
})

-- 3. GENERAL SETTINGS
vim.o.number = true
vim.o.relativenumber = true
vim.o.clipboard = "unnamedplus"
vim.o.termguicolors = true 

-- === FOLDING SETUP (Robust w/ Delay) ===
vim.api.nvim_create_autocmd({"BufEnter", "BufReadPost"}, {
  pattern = { "python", "lua" },
  callback = function()
    -- Set the settings immediately
    vim.opt_local.foldmethod = "expr"
    vim.opt_local.foldexpr = "v:lua.vim.treesitter.foldexpr()"
    
    -- Wait 200ms for Treesitter to parse, then force close all folds
    vim.defer_fn(function()
      vim.cmd("normal! zM") -- 'zM' means Close All Folds
    end, 200)
  end,
})

vim.o.foldmethod = "expr"
vim.o.foldexpr = "v:lua.vim.treesitter.foldexpr()" -- Use the built-in TS folding
vim.o.foldlevel = 99         -- Start with everything open
vim.o.foldlevelstart = 99    -- Ensure it applies on file open

-- === REMOTE CLIPBOARD SETUP (OSC 52) ===
local function copy(lines, _)
  require('vim.ui.clipboard.osc52').copy('+')(lines)
end
local function paste()
  return { vim.fn.split(vim.fn.getreg(''), '\n'), vim.fn.getregtype('') }
end
vim.g.clipboard = {
  name = 'osc52',
  copy = { ['+'] = copy, ['*'] = copy },
  paste = { ['+'] = paste, ['*'] = paste },
}

-- ==========================================================================
-- 1. AUTO-INSERT MODE
-- ==========================================================================
-- Automatically enter Insert mode when entering a terminal buffer
-- or opening a new one. This makes it feel like a real terminal.
vim.api.nvim_create_autocmd({ "TermOpen", "BufEnter" }, {
    pattern = "term://*",
    callback = function()
        vim.cmd("startinsert")
    end,
})

