module Jekyll
  module DateFilter
    MONTHS = %w(Январь Февраль Март Апрель Май Июнь Июль Август Сентябрь Октябрь Ноябрь Декабрь)

    def russian_long_month(input)
      MONTHS[input.strftime("%m").to_i - 1]
    end
  end
end

Liquid::Template.register_filter(Jekyll::DateFilter)
