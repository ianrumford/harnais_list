ExUnit.start()

defmodule HarnaisListHelperTest do
  defmacro __using__(_opts \\ []) do
    quote do
      use ExUnit.Case, async: true
      use Harnais
      alias Harnais.Error, as: HEE
      alias Harnais.Error.Status, as: HES

      import Harnais.Error,
        only: [
          harnais_error_export_result: 1
        ]

      use Harnais.Attribute
      use Harnais.Attribute.Data
    end
  end
end
