pub fn greet() -> &'static str {
    "Hello from my-app!"
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_greet() {
        assert_eq!(greet(), "Hello from my-app!");
    }
}
