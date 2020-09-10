defmodule Libvips do

  @moduledoc """
  Libvips - wrappings for libvips
  """

  @type image   :: Path.t()
  @type size    :: {non_neg_integer(), non_neg_integer()}
  @type factors :: {non_neg_integer(), non_neg_integer()}
  @type command_response :: {:ok, image()} | {:error, binary()}

  @typep to_jpeg_opt :: {:progressive?, boolean()} | {:strip?, boolean()}

  defmacrop errstr(err, code) do
    quote(do: "code: #{unquote(code)} output: #{unquote(err)}")
  end

  @doc """
  Use this function to initialize Libvips.
  Finds and stores executables into the :persistent_term
  """
  @spec find_executables() :: :ok | {:error, atom()}
  def find_executables do
    with(
      {:ok, _} <- do_find_executable(:vips,       :vips_executable,       "vips"),
      {:ok, _} <- do_find_executable(:vipsheader, :vipsheader_executable, "vipsheader")
    ) do
      :ok
    else
      err -> err
    end
  end

  @spec io_command(image(), image(), String.t(), [String.t()]) :: command_response()
  def io_command(input, output, command, opts \\ []) do
    :persistent_term.get(:vips_executable)
    |> System.cmd([command, input, output | opts], cd: "/tmp")
    |> case do
      {_resp, 0}  -> {:ok, output}
      {err, code} -> {:error, errstr(err, code)}
    end
  end

  @doc """
  Checks if the given file exists and returns size of this file
  """
  @spec get_size(image()) :: {:ok, size()} | {:error, :not_found} | {:error, String.t()}
  def get_size(input) do
    with(
      true     <- File.exists?(input),
      {res, 0} <- System.cmd(:persistent_term.get(:vipsheader_executable), [input])
    ) do
      #TODO this regex can be exploited
      [[x, y] | _] = Regex.scan(~r/: (?<x>\d*)x(?<y>\d*) uchar/, res, capture: :all_names)
      {:ok, {String.to_integer(x), String.to_integer(y)}}
    else
      false ->
        {:error, :not_found}
      {err, code} ->
        {:error, errstr(err, code)}
    end
  end

  @doc """
  Downsamples (makes the file smaller) the given file with given factors tuple
  """
  @spec subsample(image(), image(), factors()) :: command_response()
  def subsample(input, output, {xfactor, yfactor}) when is_integer(xfactor) and is_integer(yfactor) do
    io_command(input, output, "subsample", ["#{xfactor}", "#{yfactor}"])
  end

  @doc """
  Zooms (makes the file bigger) the given file with given factors tuple
  """
  @spec zoom(image(), image(), factors()) :: command_response()
  def zoom(input, output, {xfactor, yfactor}) when is_integer(xfactor) and is_integer(yfactor) do
    io_command(input, output, "zoom", ["#{xfactor}", "#{yfactor}"])
  end

  @doc """
  Converts image to the specified format with default settings
  """
  @spec convert_format(image(), :jpeg | :png | :webp, image()) :: command_response()
  def convert_format(input, :jpeg, output), do: to_jpeg(input, output)
  def convert_format(input, :png,  output), do: to_png(input, output)
  def convert_format(input, :webp, output), do: to_webp(input, output)

  @doc """
  Converts the file to webp and strips metadata (by default)
  """
  @spec to_webp(image(), image(), boolean()) :: command_response()
  def to_webp(input, output, strip? \\ true) do
    io_command(input, output, "webpsave", if(strip?, do: ["--strip"], else: []))
  end

  @doc """
  Converts the file to png and strips metadata (by default)
  """
  @spec to_png(image(), image(), boolean()) :: command_response()
  def to_png(input, output, strip? \\ true) do
    io_command(input, output, "pngsave", if(strip?, do: ["--strip"], else: []))
  end

  @doc """
  Converts the file to jpeg in progressive format with metadata stripping (by default)
  """
  @spec to_jpeg(image(), image()) :: command_response()
  def to_jpeg(input, output) do
    io_command(input, output, "jpegsave", ["--interlace", "--strip"])
  end

  @doc """
  Converts the file to jpeg in progressive format with metadata stripping (by default)
  """
  @spec to_jpeg(image(), image(), [to_jpeg_opt()]) :: command_response()
  def to_jpeg(input, output, opts) do
    progressive? =
      Keyword.get(opts, :progressive?, true)
      |> if(do: ["--interlace"], else: [])

    strip? =
      Keyword.get(opts, :strip?, true)
      |> if(do: ["--strip"], else: [])

    io_command(input, output, "jpegsave", progressive? ++ strip?)
  end

  @spec xyz_to_scrgb(image(), image()) :: command_response()
  def xyz_to_scrgb(input, output) do
    io_command(input, output, "XYZ2scRGB")
  end

  @doc """
  Scales the image with affine method to the given size
  """
  @spec resize_to(image(), image(), size(), size()) :: command_response()
  def resize_to(input, output, {current_x, current_y}, {desired_x, desired_y}) do
    x = Float.to_string(desired_x / current_x)
    y = Float.to_string(desired_y / current_y)
    io_command(input, output, "affine", ["#{x} 0 0 #{y}"])
  end

  # Helper for finding executables
  @spec do_find_executable(atom(), atom(), Path.t()) :: {:ok, Path.t()} | {:error, atom()}
  defp do_find_executable(conf_param, key, default) do
    Application.get_env(:libvips, conf_param, default)
    |> System.find_executable()
    |> case do
      nil  -> {:error, conf_param}
      path ->
        :persistent_term.put(key, path)
        {:ok, path}
    end
  end

end
