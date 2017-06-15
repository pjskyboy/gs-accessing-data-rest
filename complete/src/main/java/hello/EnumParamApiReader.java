package hello;

import com.fasterxml.classmate.TypeResolver;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import springfox.documentation.builders.OperationBuilder;
import springfox.documentation.builders.ParameterBuilder;
import springfox.documentation.service.AllowableListValues;
import springfox.documentation.spi.DocumentationType;
import springfox.documentation.spi.service.OperationBuilderPlugin;
import springfox.documentation.spi.service.ParameterBuilderPlugin;
import springfox.documentation.spi.service.contexts.OperationContext;
import springfox.documentation.spi.service.contexts.ParameterContext;
import springfox.documentation.swagger.common.SwaggerPluginSupport;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import static hello.EnumParam.ONE;

@Component
@Order(SwaggerPluginSupport.SWAGGER_PLUGIN_ORDER + 1000)
public class EnumParamApiReader  implements ParameterBuilderPlugin, OperationBuilderPlugin {
    private TypeResolver resolver;

    @Override
    public void apply(ParameterContext parameterContext) {
        final List<String>displayList = new ArrayList<>();
        List<EnumParam> enumParams = Arrays.asList((EnumParam[])EnumParam.values());
        enumParams.forEach( (enumParam -> {
            displayList.add(enumParam.getDisplay());
        }
        ));
        AllowableListValues allowableListValues = new AllowableListValues(displayList, "string");
        ParameterBuilder builder = parameterContext.parameterBuilder();
        builder.allowableValues(allowableListValues);
        builder.defaultValue(ONE.getDisplay());
    }

    @Override
    public boolean supports(DocumentationType delimiter) {
        return true;
    }

    @Override
    public void apply(OperationContext context) {
        context.operationBuilder();
    }
}
