classdef Arrangement
    %ARRANGEMENT Several matgrib plots in one figure; see matgrib.arrange.

    properties (SetAccess = private)
        Plots cell = {}
        Options struct = struct()
    end

    methods
        function a = Arrangement(plots, opts)
            a.Plots = plots;
            a.Options = opts;
        end

        function fig = build(a)
            specs = cellfun(@(p) p.build(), a.Plots, 'UniformOutput', false);
            o = a.Options;
            fig = struct('matgrib', 2, 'title', char(o.title), 'subtitle', char(o.subtitle), ...
                'caption', char(o.caption), 'ncol', o.ncol, 'aspect', o.aspect, ...
                'panels', {cellfun(@(s) s.panels{1}, specs, 'UniformOutput', false)}, ...
                'notes', {[{} cellfun(@(s) s.notes, specs, 'UniformOutput', false)]});
            fig.notes = [fig.notes{:}];
        end

        function display(a, ~)
            a.show();
        end

        function show(a)
            if matgrib.emit(), matgrib.emit(a.build()); else, a.preview(); end
        end

        function fig = preview(a)
            fig = matgrib.preview(a.build());
        end

        function s = json(a, varargin)
            s = jsonencode(a.build(), varargin{:});
        end

        function disp(a)
            fprintf('  matgrib.Arrangement of %d plot(s)\n', numel(a.Plots));
        end
    end
end
