defmodule Inky.CommandsTest do
  @moduledoc false

  use ExUnit.Case

  alias Inky.Commands
  alias Inky.Displays.Display
  alias Inky.TestIO

  import Inky.TestUtil, only: [gather_messages: 0, pos2col: 2]
  import Inky.TestVerifier, only: [load_spec: 2, check: 2]

  defp init_pixels(display) do
    for i <- 0..(display.width - 1),
        j <- 0..(display.height - 1),
        do: {{i, j}, pos2col(i, j)},
        into: %{}
  end

  setup_all do
    display = %Display{width: w, height: h, rotation: r} = Display.spec_for(:phat)
    pixels = init_pixels(display)

    %{
      display: display,
      buf_black: Inky.PixelUtil.pixels_to_bits(pixels, w, h, r, %{black: 0, miss: 1}),
      buf_red:
        Inky.PixelUtil.pixels_to_bits(pixels, w, h, r, %{red: 1, yellow: 1, accent: 1, miss: 0})
    }
  end

  describe "happy paths" do
    test "that init dispatches properly" do
      # act
      Commands.init_io(TestIO, [])

      # assert
      assert_received {:init, []}
    end

    # fail fast, just in case we have an infinite loop bug
    @tag timeout: 5
    test "that update dispatches properly when the device is never busy", ctx do
      # arrange, read_busy always returns 0
      init_opts = [read_busy: 0]
      state = Commands.init_io(TestIO, init_opts)

      # act
      :ok = Commands.update(state, ctx.display, ctx.buf_black, ctx.buf_red)

      # assert
      assert_received {:init, init_opts}
      assert TestIO.assert_expectations() == :ok
      spec = load_spec("data/success1.dat", __DIR__)
      mailbox = gather_messages()
      assert check(spec, mailbox) == {:ok, 31}
    end

    # fail fast, just in case we have an infinite loop bug
    @tag timeout: 5
    test "that update dispatches properly when the device is a little busy", ctx do
      # arrange, read_busy is a little busy each time, we expect two wait-loops.
      init_opts = [read_busy: [1, 1, 1, 0, 1, 1, 0]]
      state = Commands.init_io(TestIO, init_opts)

      # act
      :ok = Commands.update(state, ctx.display, ctx.buf_black, ctx.buf_red)

      # assert
      assert_received {:init, init_opts}
      assert TestIO.assert_expectations() == :ok
      spec = load_spec("data/success2.dat", __DIR__)
      mailbox = gather_messages()
      assert check(spec, mailbox) == {:ok, 41}
    end
  end
end
