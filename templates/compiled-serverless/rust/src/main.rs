use std::env;

use my_service::handle;
use tokio::io::{AsyncReadExt, AsyncWriteExt};
use tokio::net::TcpListener;

mod server;

fn main() {
    let arg = env::args().nth(1);
    let mode = arg.as_deref().unwrap_or("server");
    match mode {
        "function" => run_function(),
        _ => server::run(),
    }
}

fn run_function() {
    let port = env::var("FISSION_FUNCTION_PORT").unwrap_or_else(|_| "8888".to_string());
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        let listener = TcpListener::bind(format!(":{}", port)).await.unwrap();
        println!("fission function listening on :{}", port);
        loop {
            let (mut socket, _) = listener.accept().await.unwrap();
            tokio::spawn(async move {
                let mut buf = vec![0; 1024];
                socket.read(&mut buf).await.unwrap();
                let body = handle("/");
                let response = format!(
                    "HTTP/1.1 200 OK\r\nContent-Length: {}\r\n\r\n{}",
                    body.len(),
                    body
                );
                socket.write_all(response.as_bytes()).await.unwrap();
            });
        }
    });
}
