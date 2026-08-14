# frozen_string_literal: true

# Lightweight ANSI color helpers for terminal output.
# No external dependencies. Safe for piped/non-TTY output.
module Antigravity
  module Colors
    CODES = {
      reset:     "\e[0m",
      bold:      "\e[1m",
      dim:       "\e[2m",
      italic:    "\e[3m",
      # Foreground
      gray:      "\e[90m",
      red:       "\e[31m",
      green:     "\e[32m",
      yellow:    "\e[33m",
      blue:      "\e[34m",
      magenta:   "\e[35m",
      cyan:      "\e[36m",
      white:     "\e[37m",
      # Bright
      bright_green:  "\e[92m",
      bright_yellow: "\e[93m",
      bright_cyan:   "\e[96m",
    }.freeze

    def self.colorize(text, *styles)
      return text.to_s unless $stdout.tty?
      prefix = styles.map { |s| CODES[s] || "" }.join
      "#{prefix}#{text}#{CODES[:reset]}"
    end

    def self.gray(text)    = colorize(text, :gray)
    def self.dim(text)     = colorize(text, :dim)
    def self.green(text)   = colorize(text, :green)
    def self.yellow(text)  = colorize(text, :yellow)
    def self.red(text)     = colorize(text, :red)
    def self.cyan(text)    = colorize(text, :cyan)
    def self.blue(text)    = colorize(text, :blue)
    def self.magenta(text) = colorize(text, :magenta)
    def self.bold(text)    = colorize(text, :bold)
  end
end
