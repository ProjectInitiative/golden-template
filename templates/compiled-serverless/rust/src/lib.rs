pub fn handle(name: &str) -> String {
    format!("Hello, {}!", name)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_handle() {
        assert_eq!(handle("world"), "Hello, world!");
    }
}
