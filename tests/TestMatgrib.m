classdef TestMatgrib < matlab.unittest.TestCase
    % Run with:  results = runtests("tests/TestMatgrib.m")

    methods (TestClassSetup)
        function addPackage(~)
            here = fileparts(mfilename('fullpath'));
            addpath(fullfile(here, '..', '_extensions', 'matgrib', 'matlab'));
        end
    end

    methods (Static)
        function L = layers(spec)
            L = spec.panels{1}.layers;
        end

        function d = firstData(spec)
            d = spec.panels{1}.layers{1}.data;
        end
    end

    methods (Test)
        function stackedColumnsAccumulate(tc)
            T = table(["a"; "a"; "b"; "b"], ["p"; "q"; "p"; "q"], [1; 2; 3; 4], ...
                'VariableNames', {'k', 's', 'n'});
            L = TestMatgrib.layers(matgrib.gg(T, x="k", y="n", fill="s").col().build());
            d = L{1}.data;
            tc.verifyEqual(L{1}.geom, 'rect');
            tc.verifyEqual(d.ymax(2), 3, 'AbsTol', 1e-12);   % 1 + 2 at x = a
            tc.verifyEqual(d.ymin(2), 1, 'AbsTol', 1e-12);
            tc.verifyEqual(L{1}.aes, {'fill'});
        end

        function dodgedColumnsSplitTheWidth(tc)
            T = table(["a"; "a"], ["p"; "q"], [1; 2], 'VariableNames', {'k', 's', 'n'});
            d = TestMatgrib.firstData(matgrib.gg(T, x="k", y="n", fill="s").col(position="dodge", width=0.8).build());
            tc.verifyEqual(d.xmax - d.xmin, [0.4 0.4], 'AbsTol', 1e-12);
            tc.verifyEqual(d.xmax(1), d.xmin(2), 'AbsTol', 1e-12);
            tc.verifyEqual(d.ymin, [0 0]);
        end

        function discreteAxisUsesPositionsAndLabels(tc)
            T = table(categorical(["lo"; "hi"], ["lo" "hi"]), [1; 2], 'VariableNames', {'g', 'v'});
            s = matgrib.gg(T, x="g", y="v").point().build();
            tc.verifyEqual(s.panels{1}.x.type, 'discrete');
            tc.verifyEqual(s.panels{1}.x.labels, {'lo', 'hi'});
            tc.verifyEqual(s.panels{1}.layers{1}.data.x, [1 2]);
        end

        function datesAreEpochMilliseconds(tc)
            d = datetime(2024, 1, 1) + caldays(0:1)';
            s = matgrib.gg(x=d, y=[1; 2]).line().build();
            tc.verifyEqual(s.panels{1}.x.type, 'date');
            tc.verifyEqual(s.panels{1}.layers{1}.data.x(1), 1704067200000);
        end

        function linearSmoothRecoversALine(tc)
            x = (1:50)'; y = 2 + 0.5 * x;
            L = TestMatgrib.layers(matgrib.gg(x=x, y=y).smooth(method="lm", n=5).build());
            path = L{2}.data;
            tc.verifyEqual(path.y, 2 + 0.5 * path.x, 'AbsTol', 1e-9);
            band = L{1}.data;
            tc.verifyEqual(band.ymax - band.ymin, zeros(1, 5), 'AbsTol', 1e-6);
        end

        function loessFollowsLinearData(tc)
            x = linspace(0, 10, 200)'; y = 3 * x;
            L = TestMatgrib.layers(matgrib.gg(x=x, y=y).smooth(se=false, n=7).build());
            tc.verifyEqual(L{1}.data.y, 3 * L{1}.data.x, 'AbsTol', 1e-6);
        end

        function densityIntegratesToOne(tc)
            rng(3); x = randn(2000, 1);
            d = TestMatgrib.firstData(matgrib.gg(x=x).density(n=512).build());
            tc.verifyEqual(trapz(d.x, d.y), 1, 'AbsTol', 0.02);
        end

        function boxplotMatchesType7Quantiles(tc)
            y = [1:9 100]';
            L = TestMatgrib.layers(matgrib.gg(x=ones(10, 1), y=y).boxplot().build());
            box = L{1}.data;
            tc.verifyEqual([box.ymin box.ymax], [3.25 7.75], 'AbsTol', 1e-12);
            tc.verifyEqual(L{3}.data.y, 100);           % the outlier
            seg = L{2}.data;
            tc.verifyEqual(seg.yend(1:2), [9 1]);       % whiskers stop at the last inlier
        end

        function histogramCountsEveryRow(tc)
            rng(1); x = randn(500, 1);
            d = TestMatgrib.firstData(matgrib.gg(x=x).histogram(bins=12).build());
            tc.verifyEqual(sum(d.ymax - d.ymin), 500);
            tc.verifyNumElements(d.xmin, 12);
        end

        function coordFlipSwapsAxes(tc)
            T = table(["a"; "b"], [1; 2], 'VariableNames', {'k', 'n'});
            s = matgrib.gg(T, x="k", y="n").col().hline(1).coordFlip().build();
            p = s.panels{1};
            tc.verifyEqual(p.y.type, 'discrete');
            tc.verifyEqual(p.layers{1}.data.ymax - p.layers{1}.data.ymin, [0.9 0.9], 'AbsTol', 1e-12);
            tc.verifyEqual(p.layers{2}.geom, 'vline');
        end

        function pointsAreSampledReproducibly(tc)
            x = (1:10000)'; y = x;
            p = matgrib.gg(x=x, y=y).point().theme(maxPoints=500);
            a = p.build(); b = p.build();
            tc.verifyNumElements(a.panels{1}.layers{1}.data.x, 500);
            tc.verifyEqual(a.panels{1}.layers{1}.data.x, b.panels{1}.layers{1}.data.x);
            tc.verifyNotEmpty(a.notes);
        end

        function longLinesKeepTheirExtremes(tc)
            x = (1:20000)'; y = sin(x / 300); y(12345) = 50;
            d = TestMatgrib.firstData(matgrib.gg(x=x, y=y).line().theme(maxPath=400).build());
            tc.verifyLessThanOrEqual(numel(d.x), 402);
            tc.verifyEqual(max(d.y), 50);
        end

        function nanGapsSplitLines(tc)
            d = TestMatgrib.firstData(matgrib.gg(x=(1:5)', y=[1 2 NaN 4 5]').line().build());
            tc.verifyNumElements(unique(d.group), 2);
        end

        function facetLevelsFollowTheData(tc)
            T = table(["z"; "a"; "z"], [1; 2; 3], [1; 2; 3], 'VariableNames', {'f', 'x', 'y'});
            s = matgrib.gg(T, x="x", y="y").point().facet("f").build();
            tc.verifyEqual(s.panels{1}.facet.levels, {'z', 'a'});
            tc.verifyEqual(s.panels{1}.layers{1}.data.facet, {'z', 'a', 'z'});
        end

        function colourValuesAndPalettes(tc)
            T = table(["a"; "b"], [1; 2], 'VariableNames', {'g', 'v'});
            s = matgrib.gg(T, x="v", y="v", colour="g").point().scaleColour(values=["red" "#00ff00"]).build();
            tc.verifyEqual(s.panels{1}.colour.values, {'#ff0000', '#00ff00'});
            s = matgrib.gg(T, x="v", y="v", colour="v").point().build();
            tc.verifyEqual(s.panels{1}.colour.type, 'continuous');
            tc.verifyNumElements(s.panels{1}.colour.colours, 9);
        end

        function fixedColourIsNotAColumn(tc)
            s = matgrib.gg(x=1:3, y=1:3).line(colour="red").build();
            tc.verifyEqual(s.panels{1}.layers{1}.params.colour, '#ff0000');
            tc.verifyEmpty(s.panels{1}.colour);
        end

        function unknownColumnErrors(tc)
            T = table(1, 2, 'VariableNames', {'a', 'b'});
            tc.verifyError(@() matgrib.gg(T, x="a", y="nope").point().build(), 'matgrib:column');
        end

        function translatorEmitsV2Paths(tc)
            f = figure('Visible', 'off'); c = onCleanup(@() close(f));
            plot(1:3, [1 4 9], 'DisplayName', 'sq'); legend show
            s = matgrib.figureSpec(f);
            tc.verifyEqual(s.matgrib, 2);
            L = s.panels{1}.layers{1};
            tc.verifyEqual(L.geom, 'path');
            tc.verifyEqual(L.aes, {'colour', 'group'});
            tc.verifyEqual(s.panels{1}.colour.levels, {'sq'});
        end

        function translatorFlagsUnsupported(tc)
            f = figure('Visible', 'off'); c = onCleanup(@() close(f));
            surf(peaks(5));
            s = matgrib.figureSpec(f);
            tc.verifyNotEmpty(s.unsupported);
        end

        function runJobCollectsDslAndFigures(tc)
            dir = tempname; mkdir(dir); c = onCleanup(@() rmdir(dir, 's'));
            job = struct('cwd', dir, 'figdir', dir, 'imageFormat', 'svg', 'maxPoints', 2000, ...
                'maxScatter', 3000, 'strict', true, 'cells', {{ ...
                struct('id', 'c1', 'code', sprintf('matgrib.gg(x=1:3, y=1:3).line()\nfigure; plot(1:3)'), 'render', 'native'), ...
                struct('id', 'c2', 'code', 'disp(41 + 1)', 'render', 'native')}});
            file = fullfile(dir, 'job.json');
            fid = fopen(file, 'w'); fwrite(fid, jsonencode(job)); fclose(fid);
            matgrib.runJob(file);
            r = jsondecode(fileread([file '.result.json']));
            cells = r.cells;
            if ~iscell(cells), cells = num2cell(cells); end
            tc.verifyNumElements(cells{1}.figures, 2);
            tc.verifyEqual(strtrim(cells{2}.stdout), '42');
            tc.verifyFalse(isappdata(groot, 'matgrib_queue'));
        end
    end
end
