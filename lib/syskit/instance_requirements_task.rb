module Syskit
    # These tasks represent the set of InstanceRequirements that should be
    # deployed by NetworkGeneration::Engine
    class InstanceRequirementsTask < Roby::Task
        terminates

        # The instance that should be added to the network
        #
        # @return [InstanceRequirements]
        attr_accessor :requirements

        # This task is executable only if a requirement object has been set
        #
        # We don't use task arguments here as InstanceRequirements is not (yet)
        # marshallable
        def executable?
            super && requirements
        end

        # Creates the subplan required to add the given InstanceRequirements to
        # the generated network
        #
        # This is usually not used directly, use #as_plan instead
        #
        # @see InstanceRequirements#as_plan, Component#as_plan,
        #   DataService#as_plan
        def self.subplan(new_spec, *args)
            if !new_spec.kind_of?(InstanceRequirements)
                new_spec = InstanceRequirements.new([new_spec])
            end
            root = new_spec.create_proxy_task
            planner = self.new
            planner.requirements = new_spec
            root.should_start_after(planner)
            planner.schedule_as(root)
            root.planned_by(planner)
            root
        end
    end
end

