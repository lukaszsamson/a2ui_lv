defmodule A2UI.ChecksTest do
  use ExUnit.Case, async: true

  alias A2UI.Checks

  describe "evaluate_checks/4" do
    test "returns empty list for nil checks" do
      assert Checks.evaluate_checks(nil, %{}, nil) == []
    end

    test "returns empty list for empty checks" do
      assert Checks.evaluate_checks([], %{}, nil) == []
    end

    test "returns messages for failing checks" do
      checks = [
        %{
          "call" => "required",
          "args" => %{"value" => %{"path" => "/email"}},
          "message" => "Email is required"
        }
      ]

      assert Checks.evaluate_checks(checks, %{"email" => ""}, nil) == ["Email is required"]
    end

    test "returns empty list when all checks pass" do
      checks = [
        %{
          "call" => "required",
          "args" => %{"value" => %{"path" => "/email"}},
          "message" => "Email is required"
        }
      ]

      assert Checks.evaluate_checks(checks, %{"email" => "test@example.com"}, nil) == []
    end

    test "returns multiple messages for multiple failing checks" do
      checks = [
        %{
          "call" => "required",
          "args" => %{"value" => %{"path" => "/email"}},
          "message" => "Email is required"
        },
        %{
          "call" => "email",
          "args" => %{"value" => %{"path" => "/email"}},
          "message" => "Must be valid email"
        }
      ]

      messages = Checks.evaluate_checks(checks, %{"email" => ""}, nil)
      assert "Email is required" in messages
      assert "Must be valid email" in messages
    end

    test "uses default message when message is not provided" do
      checks = [
        %{
          "call" => "required",
          "args" => %{"value" => ""}
        }
      ]

      assert Checks.evaluate_checks(checks, %{}, nil) == ["Validation failed"]
    end
  end

  describe "all_pass?/4" do
    test "returns true for nil checks" do
      assert Checks.all_pass?(nil, %{}, nil) == true
    end

    test "returns true for empty checks" do
      assert Checks.all_pass?([], %{}, nil) == true
    end

    test "returns true when all checks pass" do
      checks = [
        %{
          "call" => "required",
          "args" => %{"value" => "hello"},
          "message" => "Required"
        }
      ]

      assert Checks.all_pass?(checks, %{}, nil) == true
    end

    test "returns false when any check fails" do
      checks = [
        %{
          "call" => "required",
          "args" => %{"value" => ""},
          "message" => "Required"
        }
      ]

      assert Checks.all_pass?(checks, %{}, nil) == false
    end
  end

  describe "evaluate_expression/4 - literal booleans" do
    test "returns true for literal true" do
      assert Checks.evaluate_expression(%{"true" => true}, %{}, nil, []) == true
    end

    test "returns false for literal false" do
      assert Checks.evaluate_expression(%{"false" => false}, %{}, nil, []) == false
    end
  end

  describe "evaluate_expression/4 - and expressions" do
    test "returns true when all sub-expressions are true" do
      expr = %{
        "and" => [
          %{"true" => true},
          %{"true" => true}
        ]
      }

      assert Checks.evaluate_expression(expr, %{}, nil, []) == true
    end

    test "returns false when any sub-expression is false" do
      expr = %{
        "and" => [
          %{"true" => true},
          %{"false" => false}
        ]
      }

      assert Checks.evaluate_expression(expr, %{}, nil, []) == false
    end

    test "returns true for empty and" do
      expr = %{"and" => []}
      assert Checks.evaluate_expression(expr, %{}, nil, []) == true
    end
  end

  describe "evaluate_expression/4 - or expressions" do
    test "returns true when any sub-expression is true" do
      expr = %{
        "or" => [
          %{"false" => false},
          %{"true" => true}
        ]
      }

      assert Checks.evaluate_expression(expr, %{}, nil, []) == true
    end

    test "returns false when all sub-expressions are false" do
      expr = %{
        "or" => [
          %{"false" => false},
          %{"false" => false}
        ]
      }

      assert Checks.evaluate_expression(expr, %{}, nil, []) == false
    end

    test "returns false for empty or" do
      expr = %{"or" => []}
      assert Checks.evaluate_expression(expr, %{}, nil, []) == false
    end
  end

  describe "evaluate_expression/4 - not expressions" do
    test "negates true to false" do
      expr = %{"not" => %{"true" => true}}
      assert Checks.evaluate_expression(expr, %{}, nil, []) == false
    end

    test "negates false to true" do
      expr = %{"not" => %{"false" => false}}
      assert Checks.evaluate_expression(expr, %{}, nil, []) == true
    end
  end

  describe "evaluate_expression/4 - function calls" do
    test "evaluates required function with path binding" do
      expr = %{
        "call" => "required",
        "args" => %{"value" => %{"path" => "/name"}}
      }

      assert Checks.evaluate_expression(expr, %{"name" => "Alice"}, nil, []) == true
      assert Checks.evaluate_expression(expr, %{"name" => ""}, nil, []) == false
    end

    test "evaluates email function" do
      expr = %{
        "call" => "email",
        "args" => %{"value" => %{"path" => "/email"}}
      }

      assert Checks.evaluate_expression(expr, %{"email" => "test@example.com"}, nil, []) == true
      assert Checks.evaluate_expression(expr, %{"email" => "invalid"}, nil, []) == false
    end

    test "evaluates regex function" do
      expr = %{
        "call" => "regex",
        "args" => %{
          "value" => %{"path" => "/phone"},
          "pattern" => "^\\d{3}-\\d{4}$"
        }
      }

      assert Checks.evaluate_expression(expr, %{"phone" => "123-4567"}, nil, []) == true
      assert Checks.evaluate_expression(expr, %{"phone" => "invalid"}, nil, []) == false
    end

    test "evaluates length function with min constraint" do
      expr = %{
        "call" => "length",
        "args" => %{
          "value" => %{"path" => "/name"},
          "min" => 3
        }
      }

      assert Checks.evaluate_expression(expr, %{"name" => "Alice"}, nil, []) == true
      assert Checks.evaluate_expression(expr, %{"name" => "Al"}, nil, []) == false
    end

    test "evaluates length function with max constraint" do
      expr = %{
        "call" => "length",
        "args" => %{
          "value" => %{"path" => "/name"},
          "max" => 5
        }
      }

      assert Checks.evaluate_expression(expr, %{"name" => "Alice"}, nil, []) == true
      assert Checks.evaluate_expression(expr, %{"name" => "Alexander"}, nil, []) == false
    end

    test "evaluates numeric function with min constraint" do
      expr = %{
        "call" => "numeric",
        "args" => %{
          "value" => %{"path" => "/age"},
          "min" => 18
        }
      }

      assert Checks.evaluate_expression(expr, %{"age" => 21}, nil, []) == true
      assert Checks.evaluate_expression(expr, %{"age" => 16}, nil, []) == false
    end

    test "evaluates numeric function with max constraint" do
      expr = %{
        "call" => "numeric",
        "args" => %{
          "value" => %{"path" => "/rating"},
          "max" => 5
        }
      }

      assert Checks.evaluate_expression(expr, %{"rating" => 4}, nil, []) == true
      assert Checks.evaluate_expression(expr, %{"rating" => 6}, nil, []) == false
    end

    test "returns true for unknown function" do
      expr = %{
        "call" => "unknownFunction",
        "args" => %{"value" => "test"}
      }

      assert Checks.evaluate_expression(expr, %{}, nil, []) == true
    end

    test "resolves literal values directly" do
      expr = %{
        "call" => "required",
        "args" => %{"value" => "hello"}
      }

      assert Checks.evaluate_expression(expr, %{}, nil, []) == true
    end
  end

  describe "evaluate_expression/4 - nested expressions" do
    test "evaluates nested and/or expressions" do
      # (A && B) || C where A=false, B=true, C=true
      expr = %{
        "or" => [
          %{
            "and" => [
              %{"false" => false},
              %{"true" => true}
            ]
          },
          %{"true" => true}
        ]
      }

      assert Checks.evaluate_expression(expr, %{}, nil, []) == true
    end

    test "evaluates complex form validation expression" do
      # terms_accepted AND (email OR phone)
      expr = %{
        "and" => [
          %{
            "call" => "required",
            "args" => %{"value" => %{"path" => "/terms"}}
          },
          %{
            "or" => [
              %{
                "call" => "required",
                "args" => %{"value" => %{"path" => "/email"}}
              },
              %{
                "call" => "required",
                "args" => %{"value" => %{"path" => "/phone"}}
              }
            ]
          }
        ]
      }

      # All missing - fails
      assert Checks.evaluate_expression(expr, %{"terms" => false, "email" => "", "phone" => ""}, nil, []) == false

      # Terms accepted but no contact - fails
      assert Checks.evaluate_expression(expr, %{"terms" => true, "email" => "", "phone" => ""}, nil, []) == false

      # Terms accepted with email - passes
      assert Checks.evaluate_expression(expr, %{"terms" => true, "email" => "a@b.com", "phone" => ""}, nil, []) == true

      # Terms accepted with phone - passes
      assert Checks.evaluate_expression(expr, %{"terms" => true, "email" => "", "phone" => "123"}, nil, []) == true
    end
  end

  describe "evaluate_expression/4 - version-aware path resolution" do
    test "v0.9 treats /path as absolute even with scope" do
      expr = %{
        "call" => "required",
        "args" => %{"value" => %{"path" => "/name"}}
      }

      data = %{"name" => "root", "items" => [%{"name" => "item"}]}

      # v0.9: /name is absolute -> "root"
      assert Checks.evaluate_expression(expr, data, "/items/0", version: :v0_9) == true
    end

    test "v0.8 treats /path as scoped in template context" do
      expr = %{
        "call" => "required",
        "args" => %{"value" => %{"path" => "/name"}}
      }

      data = %{"name" => "root", "items" => [%{"name" => ""}]}

      # v0.8: /name is scoped -> /items/0/name -> ""
      assert Checks.evaluate_expression(expr, data, "/items/0", version: :v0_8) == false
    end
  end

  describe "real-world check scenarios" do
    test "TextField email validation" do
      checks = [
        %{
          "call" => "required",
          "args" => %{"value" => %{"path" => "/formData/email"}},
          "returnType" => "boolean",
          "message" => "Email is required"
        },
        %{
          "call" => "email",
          "args" => %{"value" => %{"path" => "/formData/email"}},
          "returnType" => "boolean",
          "message" => "Must be valid email"
        }
      ]

      # Empty email
      data = %{"formData" => %{"email" => ""}}
      messages = Checks.evaluate_checks(checks, data, nil)
      assert "Email is required" in messages
      assert "Must be valid email" in messages

      # Invalid email
      data = %{"formData" => %{"email" => "invalid"}}
      messages = Checks.evaluate_checks(checks, data, nil)
      assert "Email is required" not in messages
      assert "Must be valid email" in messages

      # Valid email
      data = %{"formData" => %{"email" => "test@example.com"}}
      assert Checks.evaluate_checks(checks, data, nil) == []
    end

    test "ChoicePicker minimum selection validation" do
      checks = [
        %{
          "call" => "length",
          "args" => %{
            "value" => %{"path" => "/formData/interests"},
            "min" => 1
          },
          "returnType" => "boolean",
          "message" => "Select at least one"
        }
      ]

      # No selection
      data = %{"formData" => %{"interests" => []}}
      assert Checks.evaluate_checks(checks, data, nil) == ["Select at least one"]

      # Has selection
      data = %{"formData" => %{"interests" => ["code"]}}
      assert Checks.evaluate_checks(checks, data, nil) == []
    end

    test "Slider numeric range validation" do
      checks = [
        %{
          "call" => "numeric",
          "args" => %{
            "value" => %{"path" => "/formData/rating"},
            "min" => 3
          },
          "returnType" => "boolean",
          "message" => "Rating must be at least 3"
        }
      ]

      # Too low
      data = %{"formData" => %{"rating" => 2}}
      assert Checks.evaluate_checks(checks, data, nil) == ["Rating must be at least 3"]

      # Valid
      data = %{"formData" => %{"rating" => 4}}
      assert Checks.evaluate_checks(checks, data, nil) == []
    end

    test "Button form validation (all_pass? for enabled state)" do
      checks = [
        %{
          "and" => [
            %{
              "call" => "required",
              "args" => %{"value" => %{"path" => "/formData/terms"}}
            },
            %{
              "or" => [
                %{
                  "call" => "required",
                  "args" => %{"value" => %{"path" => "/formData/email"}}
                },
                %{
                  "call" => "required",
                  "args" => %{"value" => %{"path" => "/formData/phone"}}
                }
              ]
            }
          ],
          "message" => "Must accept terms AND provide email or phone"
        }
      ]

      # Button disabled - terms not accepted
      data = %{"formData" => %{"terms" => false, "email" => "a@b.com", "phone" => ""}}
      assert Checks.all_pass?(checks, data, nil) == false

      # Button disabled - no contact info
      data = %{"formData" => %{"terms" => true, "email" => "", "phone" => ""}}
      assert Checks.all_pass?(checks, data, nil) == false

      # Button enabled - has terms and email
      data = %{"formData" => %{"terms" => true, "email" => "a@b.com", "phone" => ""}}
      assert Checks.all_pass?(checks, data, nil) == true
    end
  end
end
