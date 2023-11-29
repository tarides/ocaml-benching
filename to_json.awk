(NF == 4) {
    key = $1 SUBSEP $2
    if (key in metrics) {
        multiple[key]++;
        metrics[key] = metrics[key] "," $3;
        units[key] = $4;
    } else {
        metrics[key] = $3;
        units[key] = $4;
        if (! ($1 in tests))
          nb_tests++;
        tests[$1]++;
    }
}

END {
    print "{ \"config\": {\"target_project_version\": \"" TARGET_PROJECT_VERSION "\"}, "
    print "  \"results\": ["
    for (test in tests) {
        nb_metrics = tests[test]
        print "  { \"name\": \"" test "\","
        print "    \"metrics\": ["
        prefix = test SUBSEP;
        for (key in metrics) {
            if (index(key, prefix) != 1)
                continue;
            n = length(prefix)
            metric = substr(key, n + 1, length(key) - n)
            measurements = metrics[key]
            if (key in multiple)
                measurements = "[" measurements "]"
            --nb_metrics
            comma = nb_metrics > 0 ? "," : ""
            print "      { \"name\": \"" metric "\", "
            print "        \"value\": " measurements ", "
            print "        \"units\": \"" units[key] "\" }" comma
        }
        --nb_tests
        comma = nb_tests > 0 ? "," : ""
        print "    ]"
        print "  }" comma
    }
    print "]}"
}
