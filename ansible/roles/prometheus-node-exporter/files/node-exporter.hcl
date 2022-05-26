service {
    name = "node-exporter"
    tags = ["node_exporter", "prometheus"]
    port = 9100

    check {
        id = "node-exporter"
        name = "Node Exporter healthcheck"
        http = "http://localhost:9100"
        method = "GET"
        interval =  "15s"
        timeout =  "2s"
        success_before_passing =  2
        failures_before_warning =  1
        failures_before_critical =  2
    }
}
