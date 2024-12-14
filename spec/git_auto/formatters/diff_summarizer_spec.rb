# frozen_string_literal: true

require "spec_helper"

RSpec.describe GitAuto::Formatters::DiffSummarizer do
  let(:summarizer) { described_class.new }

  describe "#summarize" do
    it "handles empty diff" do
      expect(summarizer.summarize("")).to eq("No changes")
    end

    it "summarizes single file changes" do
      diff = <<~DIFF
        diff --git a/lib/example.rb b/lib/example.rb
        index abc123..def456 100644
        --- a/lib/example.rb
        +++ b/lib/example.rb
        @@ -1,5 +1,7 @@
        class Example
          def initialize
        +    @created_at = Time.now
        +    @updated_at = Time.now
          end
        end
      DIFF

      summary = summarizer.summarize(diff)
      expect(summary).to include("[Summary: Changes across 1 files]")
      expect(summary).to include("Total: +2 lines added, -0 lines removed")
      expect(summary).to include("lib/example.rb")
    end

    it "identifies key changes" do
      diff = <<~DIFF
        diff --git a/lib/example.rb b/lib/example.rb
        index abc123..def456 100644
        --- a/lib/example.rb
        +++ b/lib/example.rb
        @@ -1,5 +1,7 @@
        class Example
        +  attr_reader :created_at, :updated_at
        +  def process_data
        +    # Implementation
        +  end
          def initialize
          end
        end
      DIFF

      summary = summarizer.summarize(diff)
      expect(summary).to include("attr_reader :created_at, :updated_at")
      expect(summary).to include("def process_data")
    end

    it "handles multiple file changes" do
      diff = <<~DIFF
        diff --git a/lib/model.rb b/lib/model.rb
        index abc123..def456 100644
        --- a/lib/model.rb
        +++ b/lib/model.rb
        @@ -1,3 +1,5 @@
        class Model
        +  belongs_to :user
        +  has_many :items
        end

        diff --git a/lib/controller.rb b/lib/controller.rb
        index 789abc..def123 100644
        --- a/controller.rb
        +++ b/controller.rb
        @@ -1,3 +1,6 @@
        class Controller
        +  def index
        +    @models = Model.all
        +  end
        end
      DIFF

      summary = summarizer.summarize(diff)
      expect(summary).to include("[Summary: Changes across 2 files]")
      expect(summary).to include("belongs_to :user")
      expect(summary).to include("has_many :items")
      expect(summary).to include("def index")
    end
  end
end
