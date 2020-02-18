
JULIA_COPY_STACKS = get(ENV, "JULIA_COPY_STACKS", "") ∈ ("1", "yes")
check_root_task = !JULIA_COPY_STACKS
const ROOT_TASK_ERROR = JavaCallError(
	"Either the environmental variable JULIA_COPY_STACKS must be 1 " *
	"OR JavaCall must be used on the root Task.")

if check_root_task
	isroottask() = Base.roottask === Base.current_task()
	assertroottask() = isroottask() ? nothing : throw(ROOT_TASK_ERROR)
else
	isroottask() = true
	assertroottask() = nothing
end
