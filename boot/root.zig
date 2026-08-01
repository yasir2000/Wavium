const entry = @import("entry/main.zig");

pub const BootError = entry.BootError;
pub const BootArch = entry.BootArch;
pub const BootHandoff = entry.BootHandoff;
pub const RuntimeAbi = entry.RuntimeAbi;
pub const RuntimeAbiRegisterNames = entry.RuntimeAbiRegisterNames;
pub const ControlState = entry.ControlState;
pub const RuntimeHandoffContract = entry.RuntimeHandoffContract;
pub const X86_64Profile = entry.X86_64Profile;

pub const X86_64_RESET_VECTOR_SYMBOL = entry.X86_64_RESET_VECTOR_SYMBOL;
pub const X86_64_STARTUP_ENTRY_SYMBOL = entry.X86_64_STARTUP_ENTRY_SYMBOL;
pub const X86_64_RUNTIME_HANDOFF_SYMBOL = entry.X86_64_RUNTIME_HANDOFF_SYMBOL;
pub const X86_64_TEMP_STACK_TOP_SYMBOL = entry.X86_64_TEMP_STACK_TOP_SYMBOL;
pub const X86_64_HANDOFF_PAYLOAD_SYMBOL = entry.X86_64_HANDOFF_PAYLOAD_SYMBOL;
pub const X86_64_BOOT_ENTRY_SYMBOL = entry.X86_64_BOOT_ENTRY_SYMBOL;

pub const detectArch = entry.detectArch;
pub const bootstrap = entry.bootstrap;
pub const runtimeAbiRegisterNamesForArch = entry.runtimeAbiRegisterNamesForArch;
pub const validateRuntimeAbiForArch = entry.validateRuntimeAbiForArch;
pub const controlRegisterNameForArch = entry.controlRegisterNameForArch;
pub const validateControlStateForArch = entry.validateControlStateForArch;
pub const runtimeHandoffContractForArch = entry.runtimeHandoffContractForArch;
pub const validateX86_64AssemblySymbolContract = entry.validateX86_64AssemblySymbolContract;
pub const validateAarch64AssemblySymbolContract = entry.validateAarch64AssemblySymbolContract;
pub const validateRiscv64AssemblySymbolContract = entry.validateRiscv64AssemblySymbolContract;
pub const validateAssemblySymbolContractForArch = entry.validateAssemblySymbolContractForArch;
pub const buildX86_64HandoffForProfile = entry.buildX86_64HandoffForProfile;

pub const CpuInitContract = entry.CpuInitContract;
pub const CpuCapabilityReport = entry.CpuCapabilityReport;
pub const cpuInitContractForArch = entry.cpuInitContractForArch;
pub const capabilityReportForArch = entry.capabilityReportForArch;
pub const validateCpuInitContract = entry.validateCpuInitContract;

pub const PageTableStrategy = entry.PageTableStrategy;
pub const EarlyMemoryLayout = entry.EarlyMemoryLayout;
pub const pageTableStrategyForArch = entry.pageTableStrategyForArch;
pub const earlyMemoryLayoutFromHandoff = entry.earlyMemoryLayoutFromHandoff;
pub const validateEarlyMemoryLayout = entry.validateEarlyMemoryLayout;

pub const ImageHeader = entry.ImageHeader;
pub const LoaderFailureAction = entry.LoaderFailureAction;
pub const IMAGE_MAGIC = entry.IMAGE_MAGIC;
pub const computeImageChecksum = entry.computeImageChecksum;
pub const validateImageHeader = entry.validateImageHeader;
pub const failureActionForError = entry.failureActionForError;
