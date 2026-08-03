module Ggc
  # Namespaced ActiveRecord models under Ggc:: back onto tables prefixed
  # with `ggc_` (Rails convention for module-scoped models).
  def self.table_name_prefix
    "ggc_"
  end
end
