pub const ActorStatus = enum {
    inactive,
    active,
    suspended,
};

pub const ActorRef = struct {
    id: u64,
    status: ActorStatus,
};
