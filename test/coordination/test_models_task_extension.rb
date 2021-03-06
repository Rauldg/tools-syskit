require 'syskit/test'

describe Syskit::Coordination::Models::TaskExtension do
    include Syskit::SelfTest

    attr_reader :component_m, :action_m
    before do
        @component_m = Syskit::TaskContext.new_submodel :name => 'Task' do
            output_port 'out', '/double'
        end
        component_m.event :monitor_failed
        @action_m = Roby::Actions::Interface.new_submodel
    end

    it "can attach data monitoring tables to the action-state" do
        component_m = self.component_m
        action_m.describe ''
        _, state_machine = action_m.action_state_machine 'test' do
            task = state component_m
            task.monitor 'thresholding', task.out_port do |value|
                value > 10
            end

            start task
        end
        assert state_machine.tasks.first.data_monitoring_table.find_monitor('thresholding')
    end

    it "attaches and activates the tables when the relevant states are started" do
        action_m.describe('').returns(component_m)
        component_m = self.component_m
        action_m.send(:define_method, :test_task) do
            component_m.as_plan
        end
        action_m.describe ''
        action_m.action_state_machine :test_machine do
            task = state test_task
            task.monitor('thresholding', task.out_port).
                trigger_on do |value|
                    value > 10
                end.
                emit task.monitor_failed_event
            start task
        end
        stub_syskit_deployment_model(component_m)
        task = action_m.test_machine.instanciate(plan)
        plan.add_mission(task)
        task.start!
        syskit_run_deployer(task.current_task_child)
        syskit_start_component(task.current_task_child)
        task.current_task_child.orocos_task.out.write(20)
        process_events
        assert task.current_task_child.monitor_failed?
    end

    it "passes arguments from the state machine to the monitors" do
        component_m = self.component_m
        recorder = flexmock
        task = nil
        action_m.describe('').required_arg('arg')
        action_m.action_state_machine :test_machine do
            task = state component_m
            task.monitor('thresholding', task.out_port, :test_arg => arg).
                trigger_on do |value|
                    recorder.called(test_arg)
                    false
                end.raise_exception
            start task
        end
        assert_equal Roby::Coordination::Models::Base::Argument.new(:test_arg, true, nil), task.data_monitoring_table.arguments[:test_arg]
        assert_equal Hash[:arg => :test_arg], task.data_monitoring_arguments

        stub_syskit_deployment_model(component_m)
        task = action_m.test_machine(:arg => 0).instanciate(plan)
        recorder.should_receive(:called).with(0).once
        plan.add_mission(task)
        task.start!
        syskit_run_deployer(task.current_task_child)
        syskit_start_component(task.current_task_child)
        task.current_task_child.orocos_task.out.write(20)
        process_events
    end
end
