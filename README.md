# telescope-corrode.nvim

This extension is probably not for you. It is a hacky way to get a `Telescope find_files` style picker non-blocking and _blazingly_ fast.

How?

1. Launch `fd` from `cwd`
2. Write output to file
3. Search file with `rg`

# Features

- _Blazingly_ fast `Telescope find_files`
- Uses order-invariant `AND` for tokens in prompt: `this here` expands to "(this*.here|here*.this)" in regex matching this, any characters in between, __and__ here
- Custom entry maker to just highlight matches and not `rg` as `AND` might get to greedy

# Why

`telescope.nvim` is great at customization, but `Telescope find_files` can be one of the pain points of the plugin. This is a somewhat cursed fix for it.

# Installation

Here is one way to install this extension with [lazy.nvim](https://github.com/folke/lazy.nvim).

```lua
{
    "fdschmidt93/telescope-corrode.nvim",
    dependencies = { "nvim-telescope/telescope.nvim", "nvim-lua/plenary.nvim" }
}
```

Make sure to

```lua
require "telescope".setup({ "$YOUR_TELESCOPE_OPTS" })
require "telescope".load_extension "corrode"
```

to appropriately setup the plugin.

## Usage

You can call this extension with vimscript

```vim
:Telescope corrode
```

or lua

```lua
require "telescope".extensions.corrode.corrode {}
```

# Naming

> `telescope-corrode.nvim` draws inspiration from the dual meaning of 'rust'. In one sense, Rust is the high-performance language in which powerful tools like fd and rg are written. In another, rust represents the chemical process of iron oxidation, where corrosion gradually spreads outwards. Similarly, this plugin integrates these Rust-written tools to extend the capabilities of Neovim, creating a pipeline that 'spreads out' or 'corrodes' through your files. It symbolizes the seamless fusion of efficiency (from Rust the language) and expansive search (reminiscent of the spreading nature of rust the oxidation process).

In case you didn't realize it, GPT-4 wrote the explanation to my naming. 

# DISCLAIMER

Please consider forking for your own customization or well-formed PRs instead to fix issues or add new features. This extension foremost serves my own needs and turned into a plugin to externalize it from my config. And maybe you want to use it to.

