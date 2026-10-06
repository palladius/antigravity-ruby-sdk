# frozen_string_literal: true

require_relative "client"
require_relative "telemetry"

module Antigravity
  module Jev
    class Router
      DEFAULT_FLASH_MODEL = "gemini-2.5-flash"
      DEFAULT_PRO_MODEL = "gemini-2.5-pro"

      RouteResult = Struct.new(:model, :complexity, :confidence, :latency_ms, keyword_init: true)

      attr_reader :client, :flash_model, :pro_model

      def initialize(client: nil, flash_model: DEFAULT_FLASH_MODEL, pro_model: DEFAULT_PRO_MODEL)
        @client = client || Jev.client
        @flash_model = flash_model
        @pro_model = pro_model
      end

      def route(prompt)
        criteria = {
          simple: "Simple queries, directory lookups, basic formatting, greetings, straightforward tasks",
          complex: "Multi-step reasoning, complex code generation, architectural design, in-depth analysis"
        }
        instructions = "Classify the complexity of this user query to select the appropriate AI model tier."

        choice, conf, resp = @client.choice(criteria, state: prompt, instructions: instructions)

        complexity = (choice.to_s == "complex") ? "complex" : "simple"
        chosen_model = (complexity == "complex") ? @pro_model : @flash_model

        RouteResult.new(
          model: chosen_model,
          complexity: complexity,
          confidence: conf || 0.90,
          latency_ms: resp&.latency_ms || 0.0
        )
      end
    end
  end
end
