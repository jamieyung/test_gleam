import gleam/bytes_builder
import gleam/erlang/process
import gleam/result
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import mist.{type Connection, type ResponseData}
import simplifile

fn not_found() {
  response.new(404)
  |> response.set_body(mist.Bytes(bytes_builder.new()))
}

fn echo_body(request: Request(Connection)) -> Response(ResponseData) {
  let content_type =
    request
    |> request.get_header("content-type")
    |> result.unwrap("text/plain")

  mist.read_body(request, 1024 * 1024 * 10)
  |> result.map(fn(req) {
    response.new(200)
    |> response.set_body(mist.Bytes(bytes_builder.from_bit_array(req.body)))
    |> response.set_header("content-type", content_type)
  })
  |> result.lazy_unwrap(fn() {
    response.new(400)
    |> response.set_body(mist.Bytes(bytes_builder.new()))
  })
}

fn append(request: Request(Connection)) -> Response(ResponseData) {
  let content_type =
    request
    |> request.get_header("content-type")
    |> result.unwrap("text/plain")

  mist.read_body(request, 1024 * 1024 * 10)
  |> result.map(fn(req) {
    let _ = simplifile.append_bits(to: "file.txt", bits: req.body)

    let assert Ok(str) = simplifile.read(from: "file.txt")

    response.new(200)
    |> response.set_body(mist.Bytes(bytes_builder.from_string(str)))
    |> response.set_header("content-type", content_type)
  })
  |> result.lazy_unwrap(fn() {
    response.new(400)
    |> response.set_body(mist.Bytes(bytes_builder.new()))
  })
}

fn reset(request: Request(Connection)) -> Response(ResponseData) {
  let content_type =
    request
    |> request.get_header("content-type")
    |> result.unwrap("text/plain")

  let _ = simplifile.write(to: "file.txt", contents: "")

  let assert Ok(str) = simplifile.read(from: "file.txt")

  response.new(200)
  |> response.set_body(mist.Bytes(bytes_builder.from_string(str)))
  |> response.set_header("content-type", content_type)
}

pub fn main() {
  fn(req: Request(Connection)) -> Response(ResponseData) {
    case request.path_segments(req) {
      ["echo"] -> echo_body(req)
      ["append"] -> append(req)
      ["reset"] -> reset(req)
      _ -> not_found()
    }
  }
  |> mist.new
  |> mist.port(3000)
  |> mist.start_http

  process.sleep_forever()
}
