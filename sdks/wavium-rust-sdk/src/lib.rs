pub const VERSION: &str = "0.1.0";

pub fn sdk_name() -> &'static str {
    "wavium-rust-sdk"
}

pub fn package_name() -> &'static str {
    "wavium"
}

/// An opaque, runtime-issued capability handle. Resource access always
/// flows through a handle like this rather than an ambient API.
pub struct CapabilityHandle {
    pub id: u64,
}

impl CapabilityHandle {
    pub fn is_valid(&self) -> bool {
        self.id != 0
    }
}

#[derive(Debug, PartialEq, Eq)]
pub enum AbiError {
    BufferTooSmall,
    InvalidBooleanEncoding,
    InvalidUtf8,
    StringTooLong,
}

/// Canonical ABI codecs. These mirror the encoding used by wavium-wit so
/// that payloads produced by this SDK are wire-compatible with the runtime.
pub fn encode_i32(value: i32, out: &mut [u8]) -> Result<usize, AbiError> {
    if out.len() < 4 {
        return Err(AbiError::BufferTooSmall);
    }
    out[0..4].copy_from_slice(&value.to_le_bytes());
    Ok(4)
}

pub fn decode_i32(data: &[u8]) -> Result<i32, AbiError> {
    if data.len() < 4 {
        return Err(AbiError::BufferTooSmall);
    }
    let mut bytes = [0u8; 4];
    bytes.copy_from_slice(&data[0..4]);
    Ok(i32::from_le_bytes(bytes))
}

pub fn encode_bool(value: bool, out: &mut [u8]) -> Result<usize, AbiError> {
    if out.is_empty() {
        return Err(AbiError::BufferTooSmall);
    }
    out[0] = if value { 1 } else { 0 };
    Ok(1)
}

pub fn decode_bool(data: &[u8]) -> Result<bool, AbiError> {
    if data.is_empty() {
        return Err(AbiError::BufferTooSmall);
    }
    match data[0] {
        0 => Ok(false),
        1 => Ok(true),
        _ => Err(AbiError::InvalidBooleanEncoding),
    }
}

pub fn encode_string(value: &str, out: &mut [u8]) -> Result<usize, AbiError> {
    if value.len() > u32::MAX as usize {
        return Err(AbiError::StringTooLong);
    }
    let required = 4 + value.len();
    if out.len() < required {
        return Err(AbiError::BufferTooSmall);
    }
    out[0..4].copy_from_slice(&(value.len() as u32).to_le_bytes());
    out[4..required].copy_from_slice(value.as_bytes());
    Ok(required)
}

pub fn decode_string(data: &[u8]) -> Result<&str, AbiError> {
    if data.len() < 4 {
        return Err(AbiError::BufferTooSmall);
    }
    let mut len_bytes = [0u8; 4];
    len_bytes.copy_from_slice(&data[0..4]);
    let len = u32::from_le_bytes(len_bytes) as usize;
    let required = 4 + len;
    if data.len() < required {
        return Err(AbiError::BufferTooSmall);
    }
    std::str::from_utf8(&data[4..required]).map_err(|_| AbiError::InvalidUtf8)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sdk_name_is_stable() {
        assert_eq!(sdk_name(), "wavium-rust-sdk");
    }

    #[test]
    fn capability_handle_validity() {
        assert!(!CapabilityHandle { id: 0 }.is_valid());
        assert!(CapabilityHandle { id: 7 }.is_valid());
    }

    #[test]
    fn abi_encode_decode_i32() {
        let mut buf = [0u8; 4];
        encode_i32(-99, &mut buf).unwrap();
        assert_eq!(decode_i32(&buf).unwrap(), -99);
    }

    #[test]
    fn abi_encode_decode_bool() {
        let mut buf = [0u8; 1];
        encode_bool(true, &mut buf).unwrap();
        assert!(decode_bool(&buf).unwrap());
        assert_eq!(decode_bool(&[9]), Err(AbiError::InvalidBooleanEncoding));
    }

    #[test]
    fn abi_encode_decode_string() {
        let mut buf = [0u8; 32];
        let used = encode_string("wavium-sdk", &mut buf).unwrap();
        assert_eq!(decode_string(&buf[..used]).unwrap(), "wavium-sdk");
    }
}
