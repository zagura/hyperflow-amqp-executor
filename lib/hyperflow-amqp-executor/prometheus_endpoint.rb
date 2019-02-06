require "prometheus/client"

module PromClient
    class MetricEndpoint
        # @@execution_log_gauge = nil
        @@execution_log_gauge = Prometheus::Client.registry.gauge(:hyperflow_execution_log, 'Hyperflow execution log metric (0 -- start, 1 -- finish)')
        @@execution_log_sub_stage_gauge = Prometheus::Client.registry.gauge(:hyperflow_execution_log_sub_stage, 'Hyperflow execution log metric for substage (0 -- start, 1 -- finish)')
        @@running_time_gauge = Prometheus::Client.registry.gauge(:hyperflow_ruinning_time, 'Hyperflow running time')

        @@execution_time_gauge = Prometheus::Client.registry.gauge(:hyperflow_execution_time, 'Hyperflow exectuion time')
        @@downloading_time_gauge = Prometheus::Client.registry.gauge(:hyperflow_downloading_time, 'Hyperflow downloading time')
        @@uploading_time_gauge = Prometheus::Client.registry.gauge(:hyperflow_uploading_time, 'Hyperflow uploading time')
        def initialize(id,jobId,procId,hfId,wfid,jobExecutable)
            @id = id
            @jobId = jobId
            @hfId = hfId
            @wfid = wfid
            @procId = procId
            @stage = jobExecutable

            @currentStage = "idle"
            @subStage = "idle"

            @startTime = Time.now
            @stagesTime = nil
            @stageStartTime = Time.now
            @logger ||= Logger.new($stdout)
            # Prometheus Gague init
            # if @@execution_log_gauge.nil?


            #     @@uploading_time_gauge.set({ jobId: @jobId, hfId: @hfId, procId: @procId,  wfId: @wfid, workerId: @id}, 0)
            # end
            self.changeStageAndSubStage("idle","idle")
            self.setGauge(@currentStage, @subStage, 0)
            @stagesTime = Hash.new
            self.log_time_of_stage_change
            self.updateReportTime()

        end
        # 0 == "start"
        # 1 == "finish"

        def setGauge(stage, subStage, value)
            @@execution_log_gauge.set({ workerId: @id , jobId: @jobId, hfId: @hfId, wfId: @wfid, procId: @procId, stage: stage, workflow_stage: @stage }, value)
            @@execution_log_sub_stage_gauge.set({ id: @id , jobId: @jobId, hfId: @hfId, wfId: @wfid, procId: @procId, subStage: subStage, workflow_stage: @stage }, value)
        end
        def changeStageAndSubStage(stage,subStage)
            self.setGauge(@currentStage, @subStage, 1)
            @currentStage = stage
            @subStage = subStage
            self.setGauge(@currentStage, @subStage, 0)
        end

        def changeSubStage(subStage)
            @subStage = subStage
            @@execution_log_sub_stage_gauge.set({ id: @id , jobId: @jobId, hfId: @hfId, wfId: @wfid, procId: @procId, subStage: @subStage, workflow_stage: @stage }, 1)
        end

        @semaphore = Mutex.new

        # Get time with ms accurracy
        def timestamp()
            return (Time.now.to_f * 1000).to_i
        end 
        def log_start_job()
            @startTime =Time.now
            @stagesTime = Hash.new
            self.log_time_of_stage_change
            self.changeStageAndSubStage("running","init")
        end

        def log_finish_job()
                self.log_time_of_stage_change
                self.changeStageAndSubStage("idle","idle")

                self.report_times "execution_times"

                @stagesTime = nil
                @startTime = nil
        end

        def log_time_of_stage_change()
            #Executor::logger.debug Time.now
            if (@subStage =="idle")
                @stageStartTime=Time.now
            else 
                @stagesTime[@subStage] = Time.now - @stageStartTime
                @stageStartTime=Time.now
            end
        end

        def updateReportTime()
            running_time = Time.now - @startTime
            @@running_time_gauge.set({wfId: @wfid, hfId: @hfId, workerId: @id , jobId: @jobId, procId: @procId}, running_time)
            @@execution_time_gauge.set({wfId: @wfid, hfId: @hfId, workerId: @id , jobId: @jobId, procId: @procId}, @stagesTime["execution"].to_i)
            @@downloading_time_gauge.set({wfId: @wfid, hfId: @hfId, workerId: @id , jobId: @jobId, procId: @procId}, @stagesTime["stage_in"].to_i)
            @@uploading_time_gauge.set({wfId: @wfid, hfId: @hfId, workerId: @id , jobId: @jobId, procId: @procId}, @stagesTime["stage_out"].to_i)
            
        end

        def log_start_subStage(subStage)
            self.log_time_of_stage_change
            self.changeSubStage(subStage)
        end
    end
end
