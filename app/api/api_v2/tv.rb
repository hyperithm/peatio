module APIv2
    class Tv < Grape::API
      helpers ::APIv2::NamedParams
  
      desc 'Get TradingView config'
      get "tv/config" do
        {
            supports_search: true,
            supports_group_request: false,
            supports_marks: false,
            supports_timescale_marks: false,
            supports_time: true,
            exchanges: [
                {
                    value: "",
                    name: "All Exchanges",
                    desc: ""
                },
                {
                    value: "HYPERITHM",
                    name: "HYPERITHM",
                    desc: "HYPERITHM Exchange"
                }
            ],
            symbols_types: [
                {
                    name: "All types",
                    value: ""
                },
                {
                    name: "Stock",
                    value: "stock"
                },
                {
                    name: "Index",
                    value: "index"
                },
                {
                    name: "Bitcoin",
                    value: "bitcoin"
                }
            ],
            supported_resolutions: ['1', '5', '15', '30', '60', '120', '240', '360', '720', 'D', '3D', 'W']
        }
      end
  
      desc 'Get TradingView current utc time'
      get "tv/time" do
        Time.now.to_i
      end
  
      desc 'Get TradingView Symbols info'
      get "tv/symbols" do
        data =  params[:symbol].split(':')
        symbol = (data.length > 1 ? data[1] : params[:symbol]).upcase

        symbolInfo = Market.where(id: symbol).first

        {
            "name": symbolInfo[:id],
            "exchange-traded": 'HYPERITHM',
            "exchange-listed": 'HYPERITHM',
  
            "timezone": "Asia/Seoul",
            "minmov": 1,
            "pricescale": symbolInfo[:bid_precision],
            "minmov2": 0,
            "pointvalue": 1,
            "type": 'bitcoin',
            "session": '24x7',
            "has_intraday": false,
            "has_no_volume": false,
            "description": symbolInfo[:id],
            "supported_resolutions": ['1', '5', '15', '30', '60', '120', '240', '360', '720', 'D', '3D', 'W'],
            "ticker": symbolInfo[:id].upcase,
            "has_intraday": true,
        }
      end
  
      desc 'Get TradingView OHLC(k line) of specific market.'
      get "/tv/history" do
        market = params[:symbol].downcase
        market.slice! '/'

        resolution = params[:resolution]
        period =
          if r = Integer(resolution) rescue nil
            r
          else
            n = resolution.length > 1 ? resolution[0] : 1
            unit = resolution.last
            n * (unit == 'D' ? 1440 : unit == 'W' ? 10080 : 1)
          end

        from = params[:from].to_i
        to = params[:to].to_i

        key = "peatio:#{market}:k:#{period}"

        ts = JSON.parse(redis.lindex(key, 0)).first
        te = JSON.parse(redis.lindex(key, -1)).first

        start = (from - ts) / 60 / period
        start = 0 if start < 0

        stop = ((to - ts) / 60 / period).ceil + 1
        stop = 0 if stop < 0

        length = redis.llen(key)

        tv = {
            t: [],
            o: [],
            h: [],
            l: [],
            c: [],
            v: [],
            s: 'ok'
        }
        k = JSON.parse('[%s]' % redis.lrange(key, start, stop).join(','))
        outOfRange = ts > to || te < from
        if k.length > 0 && !outOfRange
        k.each do |data|
            tv[:t].push data[0]
            tv[:o].push data[1]
            tv[:h].push data[2]
            tv[:l].push data[3]
            tv[:c].push data[4]
            tv[:v].push data[5]
        end
        else
        tv[:s] = "no_data"
        end

        tv
      end
  
    end
  end
  