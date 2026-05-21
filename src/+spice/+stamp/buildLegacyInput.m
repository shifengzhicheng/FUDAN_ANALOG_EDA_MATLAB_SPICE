function legacy = buildLegacyInput(circuit)
spice.util.ensureLegacyPath();
collector = spice.stamp.LegacyCollector();

for idx = 1:numel(circuit.Elements)
    circuit.Elements{idx}.exportToLegacy(collector);
end

circuit.Models.exportToLegacy(collector);

for idx = 1:numel(circuit.Probes)
    circuit.Probes{idx}.exportToLegacy(collector);
end

legacy = collector.build();
end
