require 'riot/reporter'
require 'riot/middleware'
require 'riot/context'
require 'riot/situation'
require 'riot/runnable'
require 'riot/assertion'
require 'riot/assertion_macro'

# The namespace for all of Riot.
module Riot
  # A helper for creating/defining root context instances.
  #
  # @param [String] description the description of this context
  # @param [Class] context_class the {Riot::Context} implementation to use
  # @param [lambda] &definition the context definition
  # @return [Context] the initialized {Riot::Context}
  def self.context(description, context_class = Context, &definition)
    (root_contexts << context_class.new(description, &definition)).last
  end

  # The set of {Riot::Context} instances that have no parent.
  #
  # @return [Array] instances of {Riot::Context}
  def self.root_contexts
    @root_contexts ||= []
  end

  # How to run Riot itself. This should be called +at_exit+ unless you suggested - by calling {Riot.alone!}
  # that you want to call this method yourself. If no {Riot.reporter} is set, the
  # {Riot::StoryReporter default} will be used.
  # 
  # You can change reporters by setting the manually via {Riot.reporter=} or by using one of: {Riot.dots},
  # {Riot.silently!}, or {Riot.verbose}.
  #
  # @return [Riot::Reporter] the reporter that was used
  def self.run
    the_reporter = reporter.new(Riot.reporter_options)
    the_reporter.summarize do
      root_contexts.each { |ctx| ctx.run(the_reporter) }
    end unless root_contexts.empty?
    the_reporter
  end

  # Options that configure how Riot will run.
  # 
  # @return [Hash] the options that tell Riot how to run
  def self.options
    @options ||= {
      :silent => false,
      :alone => false,
      :reporter => Riot::StoryReporter,
      :reporter_options => {:plain => false}
    }
  end

  # This means you don't want to see any output from Riot. A "quiet riot".
  def self.silently!
    Riot.options[:silent] = true
  end

  # Reponds to whether Riot is reporting silently.
  #
  # @return [Boolean]
  def self.silently?
    Riot.options[:silent] == true
  end

  # This means you don't want Riot to run tests for you. You will execute Riot.run manually.
  def self.alone!
    Riot.options[:alone] = true
  end

  # Responds to whether Riot will run +at_exit+ (false) or manually (true).
  #
  # @return [Boolean]
  def self.alone?
    Riot.options[:alone] == true
  end

  # Allows the reporter class to be changed. Do this before tests are started.
  #
  # @param [Class] reporter_class the Class that represents a {Riot::Reporter}
  def self.reporter=(reporter_class)
    Riot.options[:reporter] = reporter_class
  end

  # Returns the class for the reporter that is currently selected. If no reporter was explicitly selected,
  # {Riot::StoryReporter} will be used.
  #
  # @return [Class] the Class that represents a {Riot::Reporter}
  def self.reporter
    Riot.silently? ? Riot::SilentReporter : Riot.options[:reporter]
  end

  # Returns the options that will be passed to the Reporter when it is created.
  #
  # @return [Hash] the Hash of current options
  def self.reporter_options
    Riot.options[:reporter_options]
  end

  # @todo make this a flag that DotMatrix and Story respect and cause them to print errors/failures
  # Tells Riot to use {Riot::VerboseStoryReporter} for reporting
  def self.verbose
    Riot.reporter = Riot::VerboseStoryReporter
  end

  # Tells Riot to use {Riot::DotMatrixReporter} for reporting
  def self.dots
    Riot.reporter = Riot::DotMatrixReporter
  end

  # Tells Riot to use {Riot::PrettyDotMatrixReporter} for reporting
  def self.pretty_dots
    Riot.reporter = Riot::PrettyDotMatrixReporter
  end

  # Tells Riot to turn color off in the output
  def self.plain!
    Riot.reporter_options[:plain] = true
  end

  # Making sure to account for Riot being run as part of a larger rake task (or something similar).
  # If a child process exited with a failing status, probably don't want to run Riot tests; just exit
  # with the child status.
  at_exit do
    unless Riot.alone?
      status = $?.exitstatus unless ($?.nil? || $?.success?)
      exit(status || run.success?)
    end
  end
end # Riot

# A little bit of monkey-patch so we can have +context+ available anywhere.
class Object
  # Defining +context+ in Object itself lets us define a root +context+ in any file. Any +context+ defined
  # within a +context+ is already handled by {Riot::Context#context}.
  #
  # @param (see Riot.context)
  # @return (see Riot.context)
  def context(description, context_class = Riot::Context, &definition)
    Riot.context(description, context_class, &definition)
  end
  alias_method :describe, :context
end # Object

class Array
  def extract_options!
    last.is_a?(::Hash) ? pop : {}
  end
end

