pub fn plan(input: &str) -> &str {
    let _ = input;
    "plan: assemble a native workflow graph without network calls"
}

pub fn execute(input: &str) -> &str {
    let _ = input;
    "execute: run the next component directly inside the host-managed flow"
}

pub fn verify(input: &str) -> &str {
    let _ = input;
    "verify: confirm the workflow output without leaving the component boundary"
}

pub fn publish(input: &str) -> &str {
    let _ = input;
    "publish: emit the final artifact from native state"
}

pub fn step(input: &str) -> &str {
    match input {
        "plan" => plan(input),
        "execute" => execute(input),
        "verify" => verify(input),
        "publish" => publish(input),
        _ => "component observed input",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn stage_handlers_return_expected_outputs() {
        assert_eq!(plan("plan"), "plan: assemble a native workflow graph without network calls");
        assert_eq!(execute("execute"), "execute: run the next component directly inside the host-managed flow");
        assert_eq!(verify("verify"), "verify: confirm the workflow output without leaving the component boundary");
        assert_eq!(publish("publish"), "publish: emit the final artifact from native state");
    }

    #[test]
    fn dispatcher_maps_known_stages() {
        assert_eq!(step("plan"), "plan: assemble a native workflow graph without network calls");
        assert_eq!(step("anything-else"), "component observed input");
    }
}
