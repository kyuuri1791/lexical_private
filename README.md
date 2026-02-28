# lexical_private

`lexical_private` is a Ruby gem that provides stronger visibility control for module methods than Ruby's built-in `private`.

## Motivation

Ruby's `private` controls visibility at the object level: a private method can be called from any method on the same object, including methods defined in an including class. This is intentional and useful in many cases.

`lexical_private` offers a stricter alternative for situations where you want a method to be an internal detail of a specific module — inaccessible even to the classes that include it.

| Caller | `private` | `lexical_private` |
|---|---|---|
| Method in the same module | allowed | allowed |
| Method added by an including class | allowed | NoMethodError |
| Direct external call (`obj.method`) | NoMethodError | NoMethodError |

## Usage

1. `extend LexicalPrivate` in your module.
2. Define public methods first (they can call lexically-private methods internally).
3. Call `lexical_private` — all methods defined after this point become lexically private.

```ruby
require "lexical_private"

module M
  extend LexicalPrivate

  def public_method
    secret  # OK — defined in the same module
  end

  lexical_private

    def secret
      "shh"
    end
end

class C
  include M

  def leak
    secret  # raises NoMethodError
  end
end

C.new.public_method  # => "shh"
C.new.secret         # => NoMethodError: private method 'secret' called for an instance of C
C.new.leak           # => NoMethodError: private method 'secret' called for an instance of C
```

Lexically-private methods can freely call other lexically-private methods defined in the same module:

```ruby
module M
  extend LexicalPrivate

  def entry
    step_one
  end

  lexical_private

    def step_one
      step_two  # OK — step_two is also in M
    end

    def step_two
      "done"
    end
end
```

## How it works

When `lexical_private` is called, the gem:

1. Wraps all already-defined methods in the module to track that execution is happening "inside" the module (via a thread-local counter keyed to the module's identity).
2. Installs a `method_added` hook so that every subsequent method definition is wrapped to check that counter before running. If the counter is zero (the call came from outside the module), `NoMethodError` is raised.

Each module gets its own counter key derived from its `object_id`, so multiple modules with lexically-private methods never interfere with each other.

## Installation

Add to your `Gemfile`:

```ruby
gem "lexical_private"
```

Or install directly:

```bash
gem install lexical_private
```

## Development

```bash
bin/setup                  # install dependencies
bundle exec rake spec      # run tests
bundle exec rake rubocop   # run linter
bundle exec rake           # run both (default)
bin/console                # interactive prompt
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
