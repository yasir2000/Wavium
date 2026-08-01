//! Affinity groups: a set of entities that should be co-located on
//! the same CPU for cache locality / latency (e.g. a pipeline of
//! actors that message each other constantly). A group has one
//! assigned CPU shared by every member, resolved through
//! `scheduler.resolveCore` as a placement *preference* (same strength
//! as a soft pin) rather than a hard constraint.

const std = @import("std");
const testing = std.testing;
const entity_mod = @import("entity.zig");

pub const CoreId = entity_mod.CoreId;
pub const EntityRef = entity_mod.EntityRef;

pub const GroupId = u16;

pub const GroupError = error{ GroupNotFound, GroupFull, TooManyGroups };

pub const max_groups = 32;
pub const max_members_per_group = 16;

const Group = struct {
    members: [max_members_per_group]EntityRef,
    member_count: usize,
    assigned_cpu: ?CoreId,
};

pub const GroupTable = struct {
    groups: [max_groups]Group,
    count: usize,

    pub fn init() GroupTable {
        return .{ .groups = undefined, .count = 0 };
    }

    /// Creates a new, empty group and returns its id.
    pub fn createGroup(self: *GroupTable) GroupError!GroupId {
        if (self.count >= max_groups) return GroupError.TooManyGroups;
        const id: GroupId = @intCast(self.count);
        self.groups[self.count] = .{ .members = undefined, .member_count = 0, .assigned_cpu = null };
        self.count += 1;
        return id;
    }

    fn groupAt(self: *GroupTable, id: GroupId) GroupError!*Group {
        if (id >= self.count) return GroupError.GroupNotFound;
        return &self.groups[id];
    }

    pub fn addMember(self: *GroupTable, id: GroupId, entity: EntityRef) GroupError!void {
        const group = try self.groupAt(id);
        if (group.member_count >= max_members_per_group) return GroupError.GroupFull;
        group.members[group.member_count] = entity;
        group.member_count += 1;
    }

    /// Assigns (or reassigns) the CPU every member of the group
    /// should prefer for co-location.
    pub fn assignCpu(self: *GroupTable, id: GroupId, cpu: CoreId) GroupError!void {
        const group = try self.groupAt(id);
        group.assigned_cpu = cpu;
    }

    pub fn cpuFor(self: *const GroupTable, id: GroupId) ?CoreId {
        if (id >= self.count) return null;
        return self.groups[id].assigned_cpu;
    }

    /// Finds the group `entity` belongs to, if any.
    pub fn groupOf(self: *const GroupTable, entity: EntityRef) ?GroupId {
        for (self.groups[0..self.count], 0..) |group, i| {
            for (group.members[0..group.member_count]) |member| {
                if (EntityRef.eql(member, entity)) return @intCast(i);
            }
        }
        return null;
    }
};

test "GroupTable creates a group, adds members, and assigns a shared cpu" {
    var table = GroupTable.init();
    const gid = try table.createGroup();
    const a = EntityRef{ .kind = .actor, .id = 1 };
    const b = EntityRef{ .kind = .actor, .id = 2 };
    try table.addMember(gid, a);
    try table.addMember(gid, b);
    try table.assignCpu(gid, 4);

    try testing.expectEqual(@as(?CoreId, 4), table.cpuFor(gid));
    try testing.expectEqual(@as(?GroupId, gid), table.groupOf(a));
    try testing.expectEqual(@as(?GroupId, gid), table.groupOf(b));
}

test "GroupTable.groupOf returns null for an entity in no group" {
    var table = GroupTable.init();
    _ = try table.createGroup();
    const lonely = EntityRef{ .kind = .component, .id = 7 };
    try testing.expect(table.groupOf(lonely) == null);
}

test "GroupTable reports GroupNotFound for an invalid id" {
    var table = GroupTable.init();
    try testing.expectError(GroupError.GroupNotFound, table.assignCpu(0, 1));
}
