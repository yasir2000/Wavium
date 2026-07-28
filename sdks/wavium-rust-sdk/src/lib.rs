pub const VERSION: &str = "0.1.0";

pub fn sdk_name() -> &'static str {
    "wavium-rust-sdk"
}

pub fn package_name() -> &'static str {
    "wavium"
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sdk_name_is_stable() {
        assert_eq!(sdk_name(), "wavium-rust-sdk");
    }
}
